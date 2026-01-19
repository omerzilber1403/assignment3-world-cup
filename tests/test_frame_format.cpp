#include <iostream>
#include <string>
#include <cassert>
#include "../client/include/Frame.h"

// Test helper function
void assertStringContains(const std::string& haystack, const std::string& needle, const std::string& testName) {
    if (haystack.find(needle) == std::string::npos) {
        std::cerr << "❌ FAILED: " << testName << std::endl;
        std::cerr << "   Expected to find: '" << needle << "'" << std::endl;
        std::cerr << "   In: " << haystack << std::endl;
        exit(1);
    } else {
        std::cout << "✅ PASSED: " << testName << std::endl;
    }
}

void testConnectFrame() {
    std::cout << "\n=== Test 1: CONNECT Frame Format ===" << std::endl;
    
    Frame frame("CONNECT");
    frame.addHeader("accept-version", "1.2");
    frame.addHeader("host", "stomp.cs.bgu.ac.il");
    frame.addHeader("login", "meni");
    frame.addHeader("passcode", "films");
    
    std::string result = frame.toString();
    
    std::cout << "Generated frame:\n" << result << "---END---" << std::endl;
    
    // Check format
    assertStringContains(result, "CONNECT\n", "Frame starts with CONNECT");
    assertStringContains(result, "accept-version:1.2\n", "Contains accept-version header");
    assertStringContains(result, "host:stomp.cs.bgu.ac.il\n", "Contains host header");
    assertStringContains(result, "login:meni\n", "Contains login header");
    assertStringContains(result, "passcode:films\n", "Contains passcode header");
    
    // Check structure: should have empty line before body
    size_t doubleNewline = result.find("\n\n");
    if (doubleNewline == std::string::npos) {
        std::cerr << "❌ FAILED: Missing empty line separator between headers and body" << std::endl;
        exit(1);
    }
    std::cout << "✅ PASSED: Empty line separator exists" << std::endl;
}

void testSubscribeFrame() {
    std::cout << "\n=== Test 2: SUBSCRIBE Frame Format ===" << std::endl;
    
    Frame frame("SUBSCRIBE");
    frame.addHeader("destination", "/usa_mexico");
    frame.addHeader("id", "17");
    frame.addHeader("receipt", "73");
    
    std::string result = frame.toString();
    
    std::cout << "Generated frame:\n" << result << "---END---" << std::endl;
    
    assertStringContains(result, "SUBSCRIBE\n", "Frame starts with SUBSCRIBE");
    assertStringContains(result, "destination:/usa_mexico\n", "Contains destination header");
    assertStringContains(result, "id:17\n", "Contains id header");
    assertStringContains(result, "receipt:73\n", "Contains receipt header");
    
    std::cout << "✅ PASSED: SUBSCRIBE frame structure is correct" << std::endl;
}

void testUnsubscribeFrame() {
    std::cout << "\n=== Test 3: UNSUBSCRIBE Frame Format ===" << std::endl;
    
    Frame frame("UNSUBSCRIBE");
    frame.addHeader("id", "17");
    frame.addHeader("receipt", "82");
    
    std::string result = frame.toString();
    
    std::cout << "Generated frame:\n" << result << "---END---" << std::endl;
    
    assertStringContains(result, "UNSUBSCRIBE\n", "Frame starts with UNSUBSCRIBE");
    assertStringContains(result, "id:17\n", "Contains id header");
    assertStringContains(result, "receipt:82\n", "Contains receipt header");
    
    // CRITICAL: UNSUBSCRIBE should NOT have destination header
    if (result.find("destination") != std::string::npos) {
        std::cerr << "❌ FAILED: UNSUBSCRIBE should not contain 'destination' header" << std::endl;
        exit(1);
    }
    std::cout << "✅ PASSED: UNSUBSCRIBE correctly uses 'id' (not 'destination')" << std::endl;
}

void testSendFrameWithBody() {
    std::cout << "\n=== Test 4: SEND Frame with Body ===" << std::endl;
    
    Frame frame("SEND");
    frame.addHeader("destination", "/usa_mexico");
    
    std::string body = "user: meni\n"
                      "team a: USA\n"
                      "team b: Mexico\n"
                      "event name: Goal\n"
                      "time: 45\n"
                      "general game updates:\n"
                      "active: true\n"
                      "description:\nUSA scores!";
    
    frame.setBody(body);
    
    std::string result = frame.toString();
    
    std::cout << "Generated frame:\n" << result << "---END---" << std::endl;
    
    assertStringContains(result, "SEND\n", "Frame starts with SEND");
    assertStringContains(result, "destination:/usa_mexico\n", "Contains destination header");
    assertStringContains(result, "user: meni\n", "Body contains user");
    assertStringContains(result, "team a: USA\n", "Body contains team a");
    assertStringContains(result, "time: 45\n", "Body contains time");
    
    // Check empty line separates headers from body
    size_t headersEnd = result.find("\n\n");
    if (headersEnd == std::string::npos) {
        std::cerr << "❌ FAILED: Missing empty line between headers and body" << std::endl;
        exit(1);
    }
    
    // Check body comes after empty line
    std::string afterEmptyLine = result.substr(headersEnd + 2);
    if (afterEmptyLine.find("user: meni") != 0) {
        std::cerr << "❌ FAILED: Body should start immediately after empty line" << std::endl;
        exit(1);
    }
    
    std::cout << "✅ PASSED: SEND frame with body is correctly formatted" << std::endl;
}

void testDisconnectFrame() {
    std::cout << "\n=== Test 5: DISCONNECT Frame Format ===" << std::endl;
    
    Frame frame("DISCONNECT");
    frame.addHeader("receipt", "100");
    
    std::string result = frame.toString();
    
    std::cout << "Generated frame:\n" << result << "---END---" << std::endl;
    
    assertStringContains(result, "DISCONNECT\n", "Frame starts with DISCONNECT");
    assertStringContains(result, "receipt:100\n", "Contains receipt header");
    
    std::cout << "✅ PASSED: DISCONNECT frame structure is correct" << std::endl;
}

void testFrameParsing() {
    std::cout << "\n=== Test 6: Frame Parsing (Reverse Operation) ===" << std::endl;
    
    std::string rawFrame = "MESSAGE\n"
                          "subscription:17\n"
                          "message-id:123\n"
                          "destination:/usa_mexico\n"
                          "\n"
                          "user: john\n"
                          "team a: USA\n"
                          "event name: Goal";
    
    Frame frame = Frame::parse(rawFrame);
    
    assert(frame.getCommand() == "MESSAGE");
    std::cout << "✅ PASSED: Parsed command correctly" << std::endl;
    
    assert(frame.getHeader("subscription") == "17");
    std::cout << "✅ PASSED: Parsed subscription header" << std::endl;
    
    assert(frame.getHeader("message-id") == "123");
    std::cout << "✅ PASSED: Parsed message-id header" << std::endl;
    
    assert(frame.getHeader("destination") == "/usa_mexico");
    std::cout << "✅ PASSED: Parsed destination header" << std::endl;
    
    std::string body = frame.getBody();
    assertStringContains(body, "user: john", "Body parsed correctly");
    assertStringContains(body, "team a: USA", "Body contains team info");
}

int main() {
    std::cout << "╔═══════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║  STOMP Frame Format Tests - PDF Compliance Check    ║" << std::endl;
    std::cout << "╚═══════════════════════════════════════════════════════╝" << std::endl;
    
    try {
        testConnectFrame();
        testSubscribeFrame();
        testUnsubscribeFrame();
        testSendFrameWithBody();
        testDisconnectFrame();
        testFrameParsing();
        
        std::cout << "\n╔═══════════════════════════════════════════════════════╗" << std::endl;
        std::cout << "║  ✅ ALL TESTS PASSED!                                ║" << std::endl;
        std::cout << "║  All frames match PDF specification                  ║" << std::endl;
        std::cout << "╚═══════════════════════════════════════════════════════╝" << std::endl;
        
        return 0;
        
    } catch (const std::exception& e) {
        std::cerr << "\n❌ Test suite failed with exception: " << e.what() << std::endl;
        return 1;
    }
}
