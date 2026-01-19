#pragma once

#include "../include/ConnectionHandler.h"
#include "../include/Frame.h"
#include "../include/event.h"
#include <string>
#include <map>
#include <vector>
#include <mutex>

enum class UserCommand {
    LOGIN,
    JOIN,
    EXIT,
    LOGOUT,
    REPORT,
    SUMMARY,
    UNKNOWN
};

enum class ServerCommand {
    CONNECTED,
    ERROR,
    RECEIPT,
    MESSAGE,
    UNKNOWN
};

class StompProtocol
{
private:
    ConnectionHandler* handler;
    bool shouldTerminate;
    bool isConnected;
    
    std::string currentUserName;
    int subscriptionIdCounter;
    int receiptIdCounter;
    
    std::map<std::string, int> subscriptions;
    std::map<int, std::string> receiptActions;
    std::map<std::string, std::map<std::string, std::vector<Event>>> gameEvents;
    
    mutable std::mutex mtx;
    
    std::vector<std::string> split(const std::string& str, char delimiter);
    UserCommand parseUserCommand(const std::string& cmd);
    ServerCommand parseServerCommand(const std::string& cmd);
    
    // Command handlers
    void handleLogin(const std::vector<std::string>& args);
    void handleJoin(const std::vector<std::string>& args);
    void handleExit(const std::vector<std::string>& args);
    void handleLogout();
    void handleReport(const std::vector<std::string>& args);
    void handleSummary(const std::vector<std::string>& args);

public:
    StompProtocol();
    void setConnectionHandler(ConnectionHandler* h);
    
    void executeUserCommand(const std::string& line);
    bool handleServerFrame(const std::string& frameStr);
    
    void close();
    bool shouldLogout() const;
    bool isClientConnected() const;
};
