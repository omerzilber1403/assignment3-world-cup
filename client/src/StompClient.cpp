#include <stdlib.h>
#include <thread>
#include <iostream>
#include "../include/StompProtocol.h"
#include "../include/ConnectionHandler.h"

int main(int argc, char *argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " host port" << std::endl;
        return -1;
    }
    
    std::string host = argv[1];
    short port = atoi(argv[2]);
    
    ConnectionHandler connectionHandler(host, port);
    if (!connectionHandler.connect()) {
        std::cerr << "Cannot connect to " << host << ":" << port << std::endl;
        return 1;
    }
    
    StompProtocol protocol;
    protocol.setConnectionHandler(&connectionHandler);
    
    // Socket listener thread
    std::thread socketThread([&connectionHandler, &protocol]() {
        while (true) {
            std::string answer;
            
            if (!connectionHandler.getFrameAscii(answer, '\0')) {
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
    
    // Main thread: keyboard input
    while (true) {
        const short bufsize = 1024;
        char buf[bufsize];
        std::cin.getline(buf, bufsize);
        std::string line(buf);
        
        protocol.executeUserCommand(line);
        
        if (protocol.shouldLogout()) {
            break;
        }
    }

    socketThread.join();
    
    return 0;
}