#include <stdlib.h>
#include <thread>
#include <iostream>
#include <sstream>
#include "../include/StompProtocol.h"
#include "../include/ConnectionHandler.h"

int main(int argc, char *argv[]) {
    ConnectionHandler* connectionHandler = nullptr;
    StompProtocol protocol;
    std::thread* socketThread = nullptr;
    
    // Main thread: keyboard input
    while (true) {
        const short bufsize = 1024;
        char buf[bufsize];
        std::cin.getline(buf, bufsize);
        std::string line(buf);
        
        // Check if this is a login command and we're not connected yet
        if (line.find("login ") == 0 && !protocol.isClientConnected() && connectionHandler == nullptr) {
            // Parse login command: login host:port username password
            std::istringstream iss(line);
            std::string cmd, hostPort, username, password;
            iss >> cmd >> hostPort >> username >> password;
            
            if (hostPort.empty()) {
                std::cout << "Usage: login {host:port} {username} {password}" << std::endl;
                continue;
            }
            
            // Extract host and port
            std::string host = "127.0.0.1";
            short port = 7777;
            size_t colonPos = hostPort.find(':');
            if (colonPos != std::string::npos) {
                host = hostPort.substr(0, colonPos);
                port = std::atoi(hostPort.substr(colonPos + 1).c_str());
            } else {
                host = hostPort;
            }
            
            // Create connection
            connectionHandler = new ConnectionHandler(host, port);
            if (!connectionHandler->connect()) {
                std::cerr << "Cannot connect to " << host << ":" << port << std::endl;
                delete connectionHandler;
                connectionHandler = nullptr;
                continue;
            }
            
            protocol.setConnectionHandler(connectionHandler);
            
            // Start socket listener thread
            socketThread = new std::thread([connectionHandler, &protocol]() {
                while (true) {
                    std::string answer;
                    
                    if (!connectionHandler->getFrameAscii(answer, '\0')) {
                        std::cout << "Disconnected from server." << std::endl;
                        protocol.close();
                        break;
                    }
                    
                    bool shouldContinue = protocol.handleServerFrame(answer);
                    if (!shouldContinue) {
                        break;
                    }
                }
            });
        }
        
        // Execute command
        protocol.executeUserCommand(line);
        
        if (protocol.shouldLogout()) {
            break;
        }
    }

    if (socketThread != nullptr) {
        socketThread->join();
        delete socketThread;
    }
    
    if (connectionHandler != nullptr) {
        delete connectionHandler;
    }
    
    return 0;
}