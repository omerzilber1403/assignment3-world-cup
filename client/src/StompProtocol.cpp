#include "../include/StompProtocol.h"
#include <iostream>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <mutex>

StompProtocol::StompProtocol() :
    handler(nullptr), shouldTerminate(false), isConnected(false),
    currentUserName(""), subscriptionIdCounter(0), receiptIdCounter(0),
    subscriptions(), receiptActions(), gameEvents(), mtx()
{
}

void StompProtocol::setConnectionHandler(ConnectionHandler* h) {
    handler = h;
}

void StompProtocol::close() {
    std::lock_guard<std::mutex> lock(mtx);
    shouldTerminate = true;
    isConnected = false;
}

bool StompProtocol::shouldLogout() const {
    std::lock_guard<std::mutex> lock(mtx);
    return shouldTerminate;
}

bool StompProtocol::isClientConnected() const {
    std::lock_guard<std::mutex> lock(mtx);
    return isConnected;
}

std::vector<std::string> StompProtocol::split(const std::string& str, char delimiter) {
    std::vector<std::string> tokens;
    std::string token;
    std::istringstream tokenStream(str);
    while (std::getline(tokenStream, token, delimiter)) {
        tokens.push_back(token);
    }
    return tokens;
}

UserCommand StompProtocol::parseUserCommand(const std::string& cmd) {
    if (cmd == "login") return UserCommand::LOGIN;
    if (cmd == "join") return UserCommand::JOIN;
    if (cmd == "exit") return UserCommand::EXIT;
    if (cmd == "logout") return UserCommand::LOGOUT;
    if (cmd == "report") return UserCommand::REPORT;
    if (cmd == "summary") return UserCommand::SUMMARY;
    return UserCommand::UNKNOWN;
}

ServerCommand StompProtocol::parseServerCommand(const std::string& cmd) {
    if (cmd == "CONNECTED") return ServerCommand::CONNECTED;
    if (cmd == "ERROR") return ServerCommand::ERROR;
    if (cmd == "RECEIPT") return ServerCommand::RECEIPT;
    if (cmd == "MESSAGE") return ServerCommand::MESSAGE;
    return ServerCommand::UNKNOWN;
}

void StompProtocol::executeUserCommand(const std::string& line) {
    std::vector<std::string> args = split(line, ' ');
    if (args.empty()) return;
    
    UserCommand cmd = parseUserCommand(args[0]);
    
    // Check connection status with lock
    bool connected;
    {
        std::lock_guard<std::mutex> lock(mtx);
        connected = isConnected;
    }
    
    switch (cmd) {
        case UserCommand::LOGIN:
            handleLogin(args);
            break;
            
        case UserCommand::JOIN:
            if (!connected) {
                std::cout << "Please login first" << std::endl;
                return;
            }
            handleJoin(args);
            break;
            
        case UserCommand::EXIT:
            if (!connected) {
                std::cout << "Please login first" << std::endl;
                return;
            }
            handleExit(args);
            break;
            
        case UserCommand::LOGOUT:
            if (!connected) {
                std::cout << "Please login first" << std::endl;
                return;
            }
            handleLogout();
            break;
            
        case UserCommand::REPORT:
            if (!connected) {
                std::cout << "Please login first" << std::endl;
                return;
            }
            handleReport(args);
            break;
            
        case UserCommand::SUMMARY:
            if (!connected) {
                std::cout << "Please login first" << std::endl;
                return;
            }
            handleSummary(args);
            break;
            
        case UserCommand::UNKNOWN:
            break;
    }
}

bool StompProtocol::handleServerFrame(const std::string& frameStr) {
    Frame frame = Frame::parse(frameStr);
    ServerCommand cmd = parseServerCommand(frame.getCommand());
    
    switch (cmd) {
        case ServerCommand::CONNECTED: {
            std::lock_guard<std::mutex> lock(mtx);
            isConnected = true;
            std::cout << "Login successful" << std::endl;
            break;
        }
            
        case ServerCommand::ERROR: {
            std::string message = frame.getHeader("message");
            std::string body = frame.getBody();
            
            std::cout << "Received Error: " << message << std::endl;
            if (!body.empty()) {
                std::cout << body << std::endl;
            }
            
            close();
            return false;
        }
            
        case ServerCommand::RECEIPT: {
            std::lock_guard<std::mutex> lock(mtx);
            int id = std::stoi(frame.getHeader("receipt-id"));
            
            if (receiptActions.find(id) != receiptActions.end()) {
                std::string action = receiptActions[id];
                receiptActions.erase(id);
                
                // Unlock before I/O and close() which will re-lock
                lock.~lock_guard();
                
                if (action == "DISCONNECT") {
                    std::cout << "Disconnected properly." << std::endl;
                    close();
                    return false;
                }
                
                std::cout << action << std::endl;
            }
            break;
        }
            
        case ServerCommand::MESSAGE: {
            std::string body = frame.getBody();
            Event event(body);
            
            std::string user = "";
            std::stringstream bodyStream(body);
            std::string line;
            while (std::getline(bodyStream, line)) {
                if (line.find("user: ") == 0) {
                    user = line.substr(6);
                    break;
                }
            }
            
            std::string currentUser;
            {
                std::lock_guard<std::mutex> lock(mtx);
                currentUser = currentUserName;
            }
            
            if (user == currentUser) {
                return true;
            }
            
            std::string game_name = event.get_team_a_name() + "_" + event.get_team_b_name();
            
            {
                std::lock_guard<std::mutex> lock(mtx);
                gameEvents[game_name][user].push_back(event);
            }
            
            std::cout << "Received message from " << user << " in channel " << game_name << std::endl;
            break;
        }
            
        case ServerCommand::UNKNOWN:
            break;
    }
    
    return true;
}

// ============================================
// Command Handler Implementations
// ============================================

void StompProtocol::handleLogin(const std::vector<std::string>& args) {
    {
        std::lock_guard<std::mutex> lock(mtx);
        if (isConnected) {
            std::cout << "The client is already logged in, log out before trying again" << std::endl;
            return;
        }
    }
    
    if (args.size() < 4) {
        std::cout << "Usage: login {host:port} {username} {password}" << std::endl;
        return;
    }
    
    std::string hostPort = args[1];
    std::string host = "127.0.0.1";
    size_t colonPos = hostPort.find(':');
    if (colonPos != std::string::npos) {
        host = hostPort.substr(0, colonPos);
    } else {
        host = hostPort;
    }
    
    std::string username = args[2];
    std::string password = args[3];
    
    {
        std::lock_guard<std::mutex> lock(mtx);
        currentUserName = username;
    }
    
    Frame frame("CONNECT");
    frame.addHeader("accept-version", "1.2");
    frame.addHeader("host", host);
    frame.addHeader("login", username);
    frame.addHeader("passcode", password);
    
    handler->sendFrameAscii(frame.toString(), '\0');
}

void StompProtocol::handleJoin(const std::vector<std::string>& args) {
    if (args.size() < 2) {
        std::cout << "Usage: join {game_name}" << std::endl;
        return;
    }
    
    std::string game_name = args[1];
    
    int sub_id, receipt_id;
    {
        std::lock_guard<std::mutex> lock(mtx);
        
        if (subscriptions.count(game_name)) {
            std::cout << "Already subscribed to " << game_name << std::endl;
            return;
        }
        
        sub_id = subscriptionIdCounter++;
        receipt_id = receiptIdCounter++;
        
        subscriptions[game_name] = sub_id;
        receiptActions[receipt_id] = "Joined channel " + game_name;
    }
    
    Frame frame("SUBSCRIBE");
    frame.addHeader("destination", "/" + game_name);
    frame.addHeader("id", std::to_string(sub_id));
    frame.addHeader("receipt", std::to_string(receipt_id));
    
    handler->sendFrameAscii(frame.toString(), '\0');
}

void StompProtocol::handleExit(const std::vector<std::string>& args) {
    if (args.size() < 2) {
        std::cout << "Usage: exit {game_name}" << std::endl;
        return;
    }
    
    std::string game_name = args[1];
    
    int sub_id, receipt_id;
    {
        std::lock_guard<std::mutex> lock(mtx);
        
        if (subscriptions.find(game_name) == subscriptions.end()) {
            std::cout << "Error: Not subscribed to " << game_name << std::endl;
            return;
        }
        
        sub_id = subscriptions[game_name];
        receipt_id = receiptIdCounter++;
        
        receiptActions[receipt_id] = "Exited channel " + game_name;
        subscriptions.erase(game_name);
    }
    
    Frame frame("UNSUBSCRIBE");
    frame.addHeader("id", std::to_string(sub_id));
    frame.addHeader("receipt", std::to_string(receipt_id));
    
    handler->sendFrameAscii(frame.toString(), '\0');
}

void StompProtocol::handleLogout() {
    int receipt_id;
    {
        std::lock_guard<std::mutex> lock(mtx);
        receipt_id = receiptIdCounter++;
        receiptActions[receipt_id] = "DISCONNECT";
    }
    
    Frame frame("DISCONNECT");
    frame.addHeader("receipt", std::to_string(receipt_id));
    
    handler->sendFrameAscii(frame.toString(), '\0');
}

void StompProtocol::handleReport(const std::vector<std::string>& args) {
    if (args.size() < 2) {
        std::cout << "Usage: report {file_path}" << std::endl;
        return;
    }
    
    std::string file_path = args[1];
    
    names_and_events names_events;
    try {
        names_events = parseEventsFile(file_path);
    } catch (const std::exception& e) {
        std::cout << "Error reading file: " << e.what() << std::endl;
        return;
    }
    
    std::string game_name = names_events.team_a_name + "_" + names_events.team_b_name;
    
    {
        std::lock_guard<std::mutex> lock(mtx);
        if (subscriptions.find(game_name) == subscriptions.end()) {
            std::cout << "Error: not subscribed to " << game_name << std::endl;
            return;
        }
    }
    
    for (const Event& event : names_events.events) {
        {
            std::lock_guard<std::mutex> lock(mtx);
            gameEvents[game_name][currentUserName].push_back(event);
        }
        
        std::string body;
        body += "user: " + currentUserName + "\n";
        body += "team a: " + names_events.team_a_name + "\n";
        body += "team b: " + names_events.team_b_name + "\n";
        body += "event name: " + event.get_name() + "\n";
        body += "time: " + std::to_string(event.get_time()) + "\n";
        
        body += "general game updates:\n";
        for (const auto& kv : event.get_game_updates()) {
            body += kv.first + ":" + kv.second + "\n";
        }
        
        body += "team a updates:\n";
        for (const auto& kv : event.get_team_a_updates()) {
            body += kv.first + ":" + kv.second + "\n";
        }
        
        body += "team b updates:\n";
        for (const auto& kv : event.get_team_b_updates()) {
            body += kv.first + ":" + kv.second + "\n";
        }
        
        body += "description:\n" + event.get_discription() + "\n";
        
        Frame frame("SEND");
        frame.addHeader("destination", "/" + game_name);
        frame.setBody(body);
        
        handler->sendFrameAscii(frame.toString(), '\0');
    }
}

void StompProtocol::handleSummary(const std::vector<std::string>& args) {
    if (args.size() < 4) {
        std::cout << "Usage: summary {game_name} {user_name} {file_path}" << std::endl;
        return;
    }
    
    std::string game_name = args[1];
    std::string user_name = args[2];
    std::string file_path = args[3];
    
    // Copy events while holding lock to prevent iterator invalidation
    std::vector<Event> events;
    {
        std::lock_guard<std::mutex> lock(mtx);
        
        if (gameEvents.find(game_name) == gameEvents.end()) {
            std::cout << "No events found for game: " << game_name << std::endl;
            return;
        }
        if (gameEvents[game_name].find(user_name) == gameEvents[game_name].end()) {
            std::cout << "No events found for user: " << user_name << " in game " << game_name << std::endl;
            return;
        }
        
        events = gameEvents[game_name][user_name];
    }
    
    std::map<std::string, std::string> general_stats;
    std::map<std::string, std::string> team_a_stats;
    std::map<std::string, std::string> team_b_stats;
    
    for (const Event& ev : events) {
        for (const auto& kv : ev.get_game_updates()) {
            general_stats[kv.first] = kv.second;
        }
        for (const auto& kv : ev.get_team_a_updates()) {
            team_a_stats[kv.first] = kv.second;
        }
        for (const auto& kv : ev.get_team_b_updates()) {
            team_b_stats[kv.first] = kv.second;
        }
    }
    
    std::ofstream outfile(file_path);
    if (!outfile.is_open()) {
        std::cout << "Error: Cannot write to file: " << file_path << std::endl;
        return;
    }
    
    if (!events.empty()) {
        outfile << events[0].get_team_a_name() << " vs " << events[0].get_team_b_name() << "\n";
        outfile << "Game stats:\n";
        
        outfile << "General stats:\n";
        for (const auto& kv : general_stats) {
            outfile << kv.first << ": " << kv.second << "\n";
        }
        
        outfile << events[0].get_team_a_name() << " stats:\n";
        for (const auto& kv : team_a_stats) {
            outfile << kv.first << ": " << kv.second << "\n";
        }
        
        outfile << events[0].get_team_b_name() << " stats:\n";
        for (const auto& kv : team_b_stats) {
            outfile << kv.first << ": " << kv.second << "\n";
        }
        
        // Sort events chronologically by time before printing
        std::sort(events.begin(), events.end(), 
            [](const Event& a, const Event& b) { 
                return a.get_time() < b.get_time(); 
            });
        
        outfile << "Game event reports:\n";
        for (const Event& ev : events) {
            outfile << ev.get_time() << " - " << ev.get_name() << ":\n\n";
            outfile << ev.get_discription() << "\n\n\n";
        }
    }
    
    outfile.close();
    std::cout << "Summary written to " << file_path << std::endl;
}
