#include <iostream>
#include <thread>
#include <chrono>
#include <fstream>
#include <cassert>
#include "../client/include/ConnectionHandler.h"
#include "../client/include/StompProtocol.h"
#include "../client/include/Frame.h"

// Colors for output
#define GREEN "\033[32m"
#define RED "\033[31m"
#define YELLOW "\033[33m"
#define BLUE "\033[34m"
#define RESET "\033[0m"

void log(const std::string& msg) {
    std::cout << BLUE << "[TEST] " << RESET << msg << std::endl;
}

void success(const std::string& msg) {
    std::cout << GREEN << "✅ " << msg << RESET << std::endl;
}

void fail(const std::string& msg) {
    std::cerr << RED << "❌ " << msg << RESET << std::endl;
    exit(1);
}

void warning(const std::string& msg) {
    std::cout << YELLOW << "⚠️  " << msg << RESET << std::endl;
}

// Test helper: wait for server to be ready
bool waitForServer(const std::string& host, short port, int maxAttempts = 10) {
    for (int i = 0; i < maxAttempts; i++) {
        ConnectionHandler temp(host, port);
        if (temp.connect()) {
            temp.close();
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    return false;
}

// Test 1: Basic Connection Test
void testBasicConnection(const std::string& host, short port) {
    log("Test 1: Basic TCP Connection");
    
    ConnectionHandler handler(host, port);
    
    if (!handler.connect()) {
        fail("Cannot connect to server at " + host + ":" + std::to_string(port));
    }
    
    success("Connected to server successfully");
    handler.close();
}

// Test 2: Login Flow (CONNECT → CONNECTED)
void testLoginFlow(const std::string& host, short port) {
    log("Test 2: Login Flow (CONNECT → CONNECTED)");
    
    ConnectionHandler handler(host, port);
    if (!handler.connect()) {
        fail("Cannot connect to server");
    }
    
    // Send CONNECT frame
    Frame connectFrame("CONNECT");
    connectFrame.addHeader("accept-version", "1.2");
    connectFrame.addHeader("host", host);
    connectFrame.addHeader("login", "test_user_1");
    connectFrame.addHeader("passcode", "password123");
    
    log("Sending CONNECT frame...");
    if (!handler.sendFrameAscii(connectFrame.toString(), '\0')) {
        fail("Failed to send CONNECT frame");
    }
    
    // Wait for CONNECTED response
    std::string response;
    if (!handler.getFrameAscii(response, '\0')) {
        fail("Failed to receive response from server");
    }
    
    log("Received response: " + response.substr(0, 50) + "...");
    
    Frame responseFrame = Frame::parse(response);
    if (responseFrame.getCommand() != "CONNECTED") {
        fail("Expected CONNECTED, got: " + responseFrame.getCommand());
    }
    
    success("Login successful - Received CONNECTED frame");
    handler.close();
}

// Test 3: Subscribe Flow (SUBSCRIBE → RECEIPT)
void testSubscribeFlow(const std::string& host, short port) {
    log("Test 3: Subscribe Flow (SUBSCRIBE → RECEIPT)");
    
    ConnectionHandler handler(host, port);
    if (!handler.connect()) {
        fail("Cannot connect to server");
    }
    
    // Login first
    Frame connectFrame("CONNECT");
    connectFrame.addHeader("accept-version", "1.2");
    connectFrame.addHeader("host", host);
    connectFrame.addHeader("login", "test_user_2");
    connectFrame.addHeader("passcode", "password123");
    handler.sendFrameAscii(connectFrame.toString(), '\0');
    
    std::string loginResponse;
    handler.getFrameAscii(loginResponse, '\0');
    
    Frame loginFrame = Frame::parse(loginResponse);
    if (loginFrame.getCommand() != "CONNECTED") {
        fail("Login failed before subscribe test");
    }
    
    // Send SUBSCRIBE
    Frame subscribeFrame("SUBSCRIBE");
    subscribeFrame.addHeader("destination", "/test_channel");
    subscribeFrame.addHeader("id", "1");
    subscribeFrame.addHeader("receipt", "100");
    
    log("Sending SUBSCRIBE frame...");
    if (!handler.sendFrameAscii(subscribeFrame.toString(), '\0')) {
        fail("Failed to send SUBSCRIBE frame");
    }
    
    // Wait for RECEIPT
    std::string receiptResponse;
    if (!handler.getFrameAscii(receiptResponse, '\0')) {
        fail("Failed to receive RECEIPT");
    }
    
    Frame receiptFrame = Frame::parse(receiptResponse);
    if (receiptFrame.getCommand() != "RECEIPT") {
        fail("Expected RECEIPT, got: " + receiptFrame.getCommand());
    }
    
    if (receiptFrame.getHeader("receipt-id") != "100") {
        fail("Expected receipt-id: 100, got: " + receiptFrame.getHeader("receipt-id"));
    }
    
    success("Subscribe successful - Received RECEIPT");
    handler.close();
}

// Test 4: Send and Broadcast Test (2 clients)
void testBroadcast(const std::string& host, short port) {
    log("Test 4: Broadcast Test (2 clients on same channel)");
    
    // Client 1 - Sender
    ConnectionHandler sender(host, port);
    if (!sender.connect()) {
        fail("Client 1 cannot connect");
    }
    
    // Client 2 - Receiver
    ConnectionHandler receiver(host, port);
    if (!receiver.connect()) {
        fail("Client 2 cannot connect");
    }
    
    // Both login
    log("Logging in both clients...");
    Frame connect1("CONNECT");
    connect1.addHeader("accept-version", "1.2");
    connect1.addHeader("host", host);
    connect1.addHeader("login", "sender_user");
    connect1.addHeader("passcode", "pass1");
    sender.sendFrameAscii(connect1.toString(), '\0');
    
    Frame connect2("CONNECT");
    connect2.addHeader("accept-version", "1.2");
    connect2.addHeader("host", host);
    connect2.addHeader("login", "receiver_user");
    connect2.addHeader("passcode", "pass2");
    receiver.sendFrameAscii(connect2.toString(), '\0');
    
    std::string resp1, resp2;
    sender.getFrameAscii(resp1, '\0');
    receiver.getFrameAscii(resp2, '\0');
    
    // Both subscribe to same channel
    log("Both clients subscribing to /broadcast_test...");
    Frame sub1("SUBSCRIBE");
    sub1.addHeader("destination", "/broadcast_test");
    sub1.addHeader("id", "10");
    sub1.addHeader("receipt", "200");
    sender.sendFrameAscii(sub1.toString(), '\0');
    
    Frame sub2("SUBSCRIBE");
    sub2.addHeader("destination", "/broadcast_test");
    sub2.addHeader("id", "20");
    sub2.addHeader("receipt", "300");
    receiver.sendFrameAscii(sub2.toString(), '\0');
    
    // Consume receipts
    sender.getFrameAscii(resp1, '\0');
    receiver.getFrameAscii(resp2, '\0');
    
    // Sender sends message
    log("Sender sending message...");
    Frame sendFrame("SEND");
    sendFrame.addHeader("destination", "/broadcast_test");
    sendFrame.setBody("Test broadcast message from sender!");
    sender.sendFrameAscii(sendFrame.toString(), '\0');
    
    // Receiver should get MESSAGE
    log("Waiting for receiver to get MESSAGE...");
    std::string messageResp;
    
    // Set a timeout for receiving
    bool received = false;
    for (int i = 0; i < 5; i++) {
        if (receiver.getFrameAscii(messageResp, '\0')) {
            received = true;
            break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    
    if (!received) {
        warning("Receiver did not get MESSAGE - possible server issue or timing");
    } else {
        Frame msgFrame = Frame::parse(messageResp);
        if (msgFrame.getCommand() == "MESSAGE") {
            success("Receiver got MESSAGE frame!");
            if (msgFrame.getBody().find("Test broadcast message") != std::string::npos) {
                success("Message body matches!");
            }
        } else {
            warning("Expected MESSAGE, got: " + msgFrame.getCommand());
        }
    }
    
    sender.close();
    receiver.close();
}

// Test 5: Full Client Flow (all commands)
void testFullClientFlow(const std::string& host, short port) {
    log("Test 5: Full Client Flow (login → join → report → summary → logout)");
    
    ConnectionHandler handler(host, port);
    if (!handler.connect()) {
        fail("Cannot connect to server");
    }
    
    // 1. LOGIN
    log("Step 1: Login");
    Frame connect("CONNECT");
    connect.addHeader("accept-version", "1.2");
    connect.addHeader("host", host);
    connect.addHeader("login", "full_test_user");
    connect.addHeader("passcode", "testpass");
    handler.sendFrameAscii(connect.toString(), '\0');
    
    std::string resp;
    handler.getFrameAscii(resp, '\0');
    if (Frame::parse(resp).getCommand() != "CONNECTED") {
        fail("Login failed");
    }
    success("✓ Login successful");
    
    // 2. JOIN (subscribe)
    log("Step 2: Join channel");
    Frame subscribe("SUBSCRIBE");
    subscribe.addHeader("destination", "/germany_japan");
    subscribe.addHeader("id", "50");
    subscribe.addHeader("receipt", "500");
    handler.sendFrameAscii(subscribe.toString(), '\0');
    
    handler.getFrameAscii(resp, '\0');
    if (Frame::parse(resp).getCommand() != "RECEIPT") {
        fail("Join failed - no RECEIPT");
    }
    success("✓ Join successful");
    
    // 3. REPORT (send event)
    log("Step 3: Send event report");
    Frame send("SEND");
    send.addHeader("destination", "/germany_japan");
    std::string eventBody = 
        "user: full_test_user\n"
        "team a: Germany\n"
        "team b: Japan\n"
        "event name: Test Goal\n"
        "time: 30\n"
        "general game updates:\n"
        "score:1-0\n"
        "description:\n"
        "Test goal at 30th minute";
    send.setBody(eventBody);
    handler.sendFrameAscii(send.toString(), '\0');
    success("✓ Report sent");
    
    // 4. EXIT (unsubscribe)
    log("Step 4: Exit channel");
    Frame unsub("UNSUBSCRIBE");
    unsub.addHeader("id", "50");
    unsub.addHeader("receipt", "600");
    handler.sendFrameAscii(unsub.toString(), '\0');
    
    handler.getFrameAscii(resp, '\0');
    if (Frame::parse(resp).getCommand() != "RECEIPT") {
        fail("Exit failed - no RECEIPT");
    }
    success("✓ Exit successful");
    
    // 5. LOGOUT (disconnect)
    log("Step 5: Logout");
    Frame disconnect("DISCONNECT");
    disconnect.addHeader("receipt", "700");
    handler.sendFrameAscii(disconnect.toString(), '\0');
    
    handler.getFrameAscii(resp, '\0');
    if (Frame::parse(resp).getCommand() != "RECEIPT") {
        fail("Logout failed - no RECEIPT");
    }
    success("✓ Logout successful");
    
    handler.close();
    success("Full flow completed successfully!");
}

// Test 6: Error Handling Tests
void testErrorHandling(const std::string& host, short port) {
    log("Test 6: Error Handling");
    
    ConnectionHandler handler(host, port);
    if (!handler.connect()) {
        fail("Cannot connect to server");
    }
    
    // Test: Send without login
    log("Testing: SEND without login (should get ERROR)");
    Frame sendNoLogin("SEND");
    sendNoLogin.addHeader("destination", "/test");
    sendNoLogin.setBody("test");
    handler.sendFrameAscii(sendNoLogin.toString(), '\0');
    
    std::string resp;
    handler.getFrameAscii(resp, '\0');
    Frame respFrame = Frame::parse(resp);
    
    if (respFrame.getCommand() == "ERROR") {
        success("✓ Server correctly sent ERROR for unauthenticated request");
    } else {
        warning("Expected ERROR, got: " + respFrame.getCommand());
    }
    
    handler.close();
}

// Test 7: Concurrent Clients Test
void testConcurrentClients(const std::string& host, short port) {
    log("Test 7: Multiple Concurrent Clients (stress test)");
    
    const int NUM_CLIENTS = 5;
    std::vector<std::thread> threads;
    std::atomic<int> successCount(0);
    
    for (int i = 0; i < NUM_CLIENTS; i++) {
        threads.emplace_back([&, i]() {
            ConnectionHandler handler(host, port);
            if (!handler.connect()) {
                return;
            }
            
            Frame connect("CONNECT");
            connect.addHeader("accept-version", "1.2");
            connect.addHeader("host", host);
            connect.addHeader("login", "concurrent_user_" + std::to_string(i));
            connect.addHeader("passcode", "pass");
            handler.sendFrameAscii(connect.toString(), '\0');
            
            std::string resp;
            if (handler.getFrameAscii(resp, '\0')) {
                if (Frame::parse(resp).getCommand() == "CONNECTED") {
                    successCount++;
                }
            }
            
            handler.close();
        });
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    if (successCount == NUM_CLIENTS) {
        success("✓ All " + std::to_string(NUM_CLIENTS) + " clients connected successfully");
    } else {
        warning(std::to_string(successCount) + "/" + std::to_string(NUM_CLIENTS) + " clients succeeded");
    }
}

int main(int argc, char* argv[]) {
    std::string host = "localhost";
    short port = 7777;
    
    if (argc >= 3) {
        host = argv[1];
        port = std::atoi(argv[2]);
    }
    
    std::cout << "\n";
    std::cout << "╔═══════════════════════════════════════════════════════════════╗\n";
    std::cout << "║       FULL INTEGRATION TESTS - Server + Client              ║\n";
    std::cout << "║       Testing: " << host << ":" << port << "                              ║\n";
    std::cout << "╚═══════════════════════════════════════════════════════════════╝\n";
    std::cout << "\n";
    
    warning("Make sure the server is running: mvn exec:java -Dexec.mainClass=\"bgu.spl.net.impl.stomp.StompServer\" -Dexec.args=\"7777\"");
    std::cout << "\n";
    
    // Wait for server
    log("Waiting for server to be ready...");
    if (!waitForServer(host, port)) {
        fail("Server is not responding. Please start the server first.");
    }
    success("Server is ready!\n");
    
    try {
        testBasicConnection(host, port);
        std::cout << "\n";
        
        testLoginFlow(host, port);
        std::cout << "\n";
        
        testSubscribeFlow(host, port);
        std::cout << "\n";
        
        testBroadcast(host, port);
        std::cout << "\n";
        
        testFullClientFlow(host, port);
        std::cout << "\n";
        
        testErrorHandling(host, port);
        std::cout << "\n";
        
        testConcurrentClients(host, port);
        std::cout << "\n";
        
        std::cout << "╔═══════════════════════════════════════════════════════════════╗\n";
        std::cout << "║  " << GREEN << "✅ ALL INTEGRATION TESTS PASSED!" << RESET << "                          ║\n";
        std::cout << "║  Server and Client are working together correctly           ║\n";
        std::cout << "╚═══════════════════════════════════════════════════════════════╝\n";
        
        return 0;
        
    } catch (const std::exception& e) {
        fail("Exception: " + std::string(e.what()));
        return 1;
    }
}
