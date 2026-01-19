# STOMP Client Implementation Plan

## Overview

Transform the single-threaded echo client into a two-threaded STOMP client that simultaneously handles keyboard input and server messages. The client must support 6 commands (login, join, exit, report, summary, logout) and properly handle 4 server frame types (CONNECTED, MESSAGE, RECEIPT, ERROR).

**Key Insight from Reference Implementations:**
- **Guy's approach:** Separate Frame class for parsing (more modular, reusable)
- **Yael's approach:** Inline parsing in StompProtocol (simpler, fewer files)
- **Our choice:** Follow Guy's modular approach with Frame class for better code organization

---

## Architecture

```
Main Thread (Keyboard)          Socket Listener Thread
┌─────────────────────┐        ┌──────────────────────┐
│ Read from stdin     │        │ while(!shouldTerminate)│
│ Parse command       │        │   getFrameAscii()    │
│ StompProtocol::     │        │   processServer      │
│   processInput()    │        │   Response()         │
│ ConnectionHandler:: │        │   Display messages   │
│   sendFrameAscii()  │        │                      │
└─────────────────────┘        └──────────────────────┘
         │                              │
         └──── ConnectionHandler ───────┘
                (shared socket)
```

**Thread Coordination:**
- `bool shouldTerminate` flag signals both threads to exit
- `bool isConnected` flag tracks login state
- `std::mutex mtx` protects shared state (Yael's improvement over Guy)

---

## Current Implementation Status

### ✅ Already Implemented
- **ConnectionHandler** - Complete with `getFrameAscii()`, `sendFrameAscii()` methods
- **Event class** - Complete with getters, has empty `Event(const std::string& frame_body)` constructor (needs implementation)
- **parseEventsFile()** - Complete JSON parser function
- **StompProtocol.h** - Empty stub, needs full implementation
- **StompClient.cpp** - Empty stub with only `return 0;`
- **Makefile** - Has targets for both EchoClient and StompWCIClient, needs Frame.o added

### ❌ Not Implemented Yet
- **Frame class** - Does not exist, needs to be created
- **StompProtocol implementation** - Class is empty, all methods need implementation
- **StompClient main** - Empty stub, needs two-thread implementation
- **Event frame body parser** - Constructor exists but is empty

---

## STEP 1: Frame Class Foundation

**File:** [client/include/Frame.h](../../client/include/Frame.h) - **CREATE NEW FILE**  
**File:** [client/src/Frame.cpp](../../client/src/Frame.cpp) - **CREATE NEW FILE**

### Purpose
Create STOMP frame representation for parsing server responses and building client requests. This provides clean separation between protocol logic and frame serialization.

**Note:** This file does not exist yet and must be created from scratch.

### Implementation Details

#### Frame.h Structure
```cpp
#pragma once
#include <string>
#include <map>

class Frame {
private:
    std::string command;                         // CONNECT, SEND, MESSAGE, etc.
    std::map<std::string, std::string> headers;  // Header key-value pairs
    std::string body;                            // Frame body content

public:
    Frame(std::string command);
    Frame();  // Default constructor for parsing
    
    // Getters/Setters
    std::string getCommand() const;
    void addHeader(const std::string& key, const std::string& val);
    std::string getHeader(const std::string& key) const;
    bool hasHeader(const std::string& key) const;
    std::map<std::string, std::string> getHeaders() const;
    std::string getBody() const;
    void setBody(const std::string& body);
    
    // Conversion methods
    std::string toString() const;              // Frame → string (for sending)
    static Frame parse(const std::string& msg); // string → Frame (for receiving)
};
```

### Key Methods Implementation

#### **`toString()`** - Serialize frame to STOMP format
```cpp
std::string Frame::toString() const {
    std::string result = command + "\n";
    
    // Add headers
    for (const auto& [key, value] : headers) {
        result += key + ":" + value + "\n";
    }
    
    // Blank line separates headers from body
    result += "\n";
    
    // Add body if present
    if (!body.empty()) {
        result += body;
    }
    
    return result;
    // Note: ConnectionHandler adds null terminator
}
```

#### **`parse(string msg)`** - Parse received frame
```cpp
static Frame Frame::parse(const std::string& msg) {
    Frame frame;
    std::stringstream stream(msg);
    std::string line;
    
    // First line is command
    std::getline(stream, line);
    frame.command = line;
    
    // Parse headers until blank line
    while (std::getline(stream, line)) {
        if (line.empty()) {
            // Rest is body
            std::string body_content;
            char c;
            while (stream.get(c)) {
                body_content += c;
            }
            frame.body = body_content;
            break;
        }
        
        // Parse header (key:value)
        size_t colon = line.find(':');
        if (colon != std::string::npos) {
            std::string key = line.substr(0, colon);
            std::string value = line.substr(colon + 1);
            frame.headers[key] = value;
        }
    }
    
    return frame;
}
```

### Best Practices from References

✅ **From Guy:** Separate Frame class with parse() and toString() methods  
✅ **From Yael:** Simple inline parsing using stringstream  
✅ **Our improvement:** Combine both - modular Frame class with clean stringstream parsing

### Testing
- Create CONNECT frame, verify `toString()` format
- Parse CONNECTED response, verify headers extracted
- Parse MESSAGE with multi-line body, verify body preserved
- Test edge cases: no body, no headers, empty frame

**Completion Criteria:**
✅ Frame class compiles without errors  
✅ `toString()` produces valid STOMP format  
✅ `parse()` correctly extracts command/headers/body  
✅ Edge cases handled gracefully  

---

## STEP 2: StompProtocol Business Logic

**File:** [client/include/StompProtocol.h](../../client/include/StompProtocol.h) - **EXISTS BUT EMPTY**  
**File:** [client/src/StompProtocol.cpp](../../client/src/StompProtocol.cpp) - **CREATE NEW FILE**

### Purpose
Central business logic for processing keyboard commands and server responses. Manages all client state including subscriptions, receipts, and event storage.

**Current State:** StompProtocol.h exists with empty class definition. Need to add all members and create implementation file.

### Class State
```cpp
#include "Frame.h"
#include "ConnectionHandler.h"
#include "event.h"
#include <string>
#include <map>
#include <vector>
#include <mutex>

class StompProtocol {
private:
    ConnectionHandler* handler;
    bool shouldTerminate;
    bool isConnected;
    
    std::string currentUserName;
    int subscriptionIdCounter;
    int receiptIdCounter;
    
    // Subscription tracking: channel → subscriptionId
    std::map<std::string, int> subscriptions;
    
    // Receipt tracking: receiptId → action description
    std::map<int, std::string> receiptActions;
    
    // Event storage: game → username → vector<Event>
    std::map<std::string, std::map<std::string, std::vector<Event>>> gameEvents;
    
    std::mutex mtx;  // Protect shared state
    
    // Helper methods
    std::vector<std::string> split(const std::string& str, char delimiter);

public:
    StompProtocol();
    void setConnectionHandler(ConnectionHandler* h);
    
    // Called by keyboard thread
    void processKeyboardCommand(const std::string& line);
    
    // Called by socket thread
    bool processServerFrame(const std::string& frameStr);
    
    // State queries
    void close();
    bool shouldLogout() const;
    bool isClientConnected() const;
};
```

### Command Implementations

#### **login {host:port} {username} {password}**

**Purpose:** Connect to server and authenticate

**Implementation:**
```cpp
if (command == "login") {
    if (isConnected) {
        std::cout << "The client is already logged in, log out before trying again" << std::endl;
        return;
    }
    if (args.size() < 4) {
        std::cout << "Usage: login {host:port} {username} {password}" << std::endl;
        return;
    }
    
    // Parse host:port
    std::string hostPort = args[1];
    std::string host = "127.0.0.1";
    size_t colonPos = hostPort.find(':');
    if (colonPos != std::string::npos) {
        host = hostPort.substr(0, colonPos);
    } else {
        host = hostPort;  // No port specified, use host as-is
    }
    
    std::string username = args[2];
    std::string password = args[3];
    currentUserName = username;
    
    // Build CONNECT frame
    Frame frame("CONNECT");
    frame.addHeader("accept-version", "1.2");
    frame.addHeader("host", host);
    frame.addHeader("login", username);
    frame.addHeader("passcode", password);
    
    handler->sendFrameAscii(frame.toString(), '\0');
}
```

**Best Practice from Yael:** Check if already logged in before attempting login

---

#### **join {game_name}**

**Purpose:** Subscribe to a game channel

**Implementation:**
```cpp
if (command == "join") {
    if (args.size() < 2) return;
    std::string game_name = args[1];
    
    // Check if already subscribed (optional but good UX)
    if (subscriptions.count(game_name)) {
        std::cout << "Already subscribed to " << game_name << std::endl;
        return;
    }
    
    int sub_id = subscriptionIdCounter++;
    int receipt_id = receiptIdCounter++;
    
    subscriptions[game_name] = sub_id;
    receiptActions[receipt_id] = "Joined channel " + game_name;
    
    // Build SUBSCRIBE frame
    Frame frame("SUBSCRIBE");
    frame.addHeader("destination", "/" + game_name);
    frame.addHeader("id", std::to_string(sub_id));
    frame.addHeader("receipt", std::to_string(receipt_id));
    
    handler->sendFrameAscii(frame.toString(), '\0');
}
```

**Note:** Yael adds "/" prefix to destination, Guy doesn't. Both work - server strips it.

---

#### **exit {game_name}**

**Purpose:** Unsubscribe from a game channel

**Implementation:**
```cpp
if (command == "exit") {
    if (args.size() < 2) return;
    std::string game_name = args[1];
    
    // Validate subscription exists
    if (subscriptions.find(game_name) == subscriptions.end()) {
        std::cout << "Error: Not subscribed to " << game_name << std::endl;
        return;
    }
    
    int sub_id = subscriptions[game_name];
    int receipt_id = receiptIdCounter++;
    
    receiptActions[receipt_id] = "Exited channel " + game_name;
    subscriptions.erase(game_name);  // Remove immediately
    
    // Build UNSUBSCRIBE frame
    Frame frame("UNSUBSCRIBE");
    frame.addHeader("id", std::to_string(sub_id));
    frame.addHeader("receipt", std::to_string(receipt_id));
    
    handler->sendFrameAscii(frame.toString(), '\0');
}
```

**Best Practice from Yael:** Validate subscription before unsubscribing

---

#### **report {file_path}**

**Purpose:** Send game events from JSON file to subscribed channel

**Critical Requirement:** MUST validate subscription before sending (not in PDF but logical)

**Implementation:**
```cpp
if (command == "report") {
    if (args.size() < 2) return;
    std::string file_path = args[1];
    
    // Parse JSON file
    names_and_events nne;
    try {
        nne = parseEventsFile(file_path);
    } catch (const std::exception& e) {
        std::cout << "Error reading file: " << e.what() << std::endl;
        return;
    }
    
    std::string game_name = nne.team_a_name + "_" + nne.team_b_name;
    
    // CRITICAL: Validate subscription (Guy doesn't do this, Yael doesn't either, but we should!)
    if (subscriptions.find(game_name) == subscriptions.end()) {
        std::cout << "Error: not subscribed to " << game_name << std::endl;
        return;
    }
    
    // OPTIONAL: Sort events (Yael does this for halftime handling)
    // For simplicity, we can skip sorting and send in file order
    
    // Send each event as separate SEND frame
    for (const Event& event : nne.events) {
        // Store locally first (for our own summary)
        gameEvents[game_name][currentUserName].push_back(event);
        
        // Build event body
        std::string body;
        body += "user: " + currentUserName + "\n";
        body += "team a: " + nne.team_a_name + "\n";
        body += "team b: " + nne.team_b_name + "\n";
        body += "event name: " + event.get_name() + "\n";
        body += "time: " + std::to_string(event.get_time()) + "\n";
        
        body += "general game updates:\n";
        for (const auto& [key, val] : event.get_game_updates()) {
            body += key + ":" + val + "\n";
        }
        
        body += "team a updates:\n";
        for (const auto& [key, val] : event.get_team_a_updates()) {
            body += key + ":" + val + "\n";
        }
        
        body += "team b updates:\n";
        for (const auto& [key, val] : event.get_team_b_updates()) {
            body += key + ":" + val + "\n";
        }
        
        body += "description:\n" + event.get_discription() + "\n";
        
        // Build SEND frame
        Frame frame("SEND");
        frame.addHeader("destination", "/" + game_name);
        frame.setBody(body);
        
        handler->sendFrameAscii(frame.toString(), '\0');
    }
}
```

**Event Body Format:**
```
user: {username}
team a: {team_a_name}
team b: {team_b_name}
event name: {event_name}
time: {time}
general game updates:
    key:value
    key:value
team a updates:
    key:value
team b updates:
    key:value
description:
{multi-line description}
```

**Key Differences:**
- **Guy:** Doesn't validate subscription before sending
- **Yael:** Sorts events by halftime (complex logic)
- **Our approach:** Validate subscription, send in file order (simpler)

---

#### **summary {game_name} {username} {file_path}**

**Purpose:** Generate summary file from received events

**Implementation:**
```cpp
if (command == "summary") {
    if (args.size() < 4) return;
    std::string game_name = args[1];
    std::string user_name = args[2];
    std::string file_path = args[3];
    
    // Validate we have events
    if (gameEvents.find(game_name) == gameEvents.end()) {
        std::cout << "No events found for game: " << game_name << std::endl;
        return;
    }
    if (gameEvents[game_name].find(user_name) == gameEvents[game_name].end()) {
        std::cout << "No events found for user: " << user_name << " in game " << game_name << std::endl;
        return;
    }
    
    std::vector<Event> events = gameEvents[game_name][user_name];
    
    // OPTIONAL: Sort events (Yael does, Guy doesn't mention)
    // For now, assume events are already in chronological order
    
    // Aggregate stats (latest values win)
    std::map<std::string, std::string> general_stats;
    std::map<std::string, std::string> team_a_stats;
    std::map<std::string, std::string> team_b_stats;
    
    for (const Event& ev : events) {
        for (const auto& [key, val] : ev.get_game_updates()) {
            general_stats[key] = val;
        }
        for (const auto& [key, val] : ev.get_team_a_updates()) {
            team_a_stats[key] = val;
        }
        for (const auto& [key, val] : ev.get_team_b_updates()) {
            team_b_stats[key] = val;
        }
    }
    
    // Write to file
    std::ofstream outfile(file_path);
    if (!outfile.is_open()) {
        std::cout << "Error: Cannot write to file: " << file_path << std::endl;
        return;
    }
    
    if (!events.empty()) {
        outfile << events[0].get_team_a_name() << " vs " << events[0].get_team_b_name() << "\n";
        outfile << "Game stats:\n";
        
        outfile << "General stats:\n";
        for (const auto& [key, val] : general_stats) {
            outfile << key << ": " << val << "\n";
        }
        
        outfile << events[0].get_team_a_name() << " stats:\n";
        for (const auto& [key, val] : team_a_stats) {
            outfile << key << ": " << val << "\n";
        }
        
        outfile << events[0].get_team_b_name() << " stats:\n";
        for (const auto& [key, val] : team_b_stats) {
            outfile << key << ": " << val << "\n";
        }
        
        outfile << "Game event reports:\n";
        for (const Event& ev : events) {
            outfile << ev.get_time() << " - " << ev.get_name() << ":\n\n";
            outfile << ev.get_discription() << "\n\n\n";
        }
    }
    
    outfile.close();
    std::cout << "Summary written to " << file_path << std::endl;
}
```

**Output Format (from PDF page 14):**
```
{team_a} vs {team_b}
Game stats:
General stats:
{key}: {value}
...
{team_a} stats:
{key}: {value}
...
{team_b} stats:
{key}: {value}
...
Game event reports:
{time} - {event_name}:

{description}


```

**Note:** Events should be in chronological order (time ascending)

---

#### **logout**

**Purpose:** Disconnect from server gracefully

**Implementation:**
```cpp
if (command == "logout") {
    int receipt_id = receiptIdCounter++;
    receiptActions[receipt_id] = "DISCONNECT";
    
    Frame frame("DISCONNECT");
    frame.addHeader("receipt", std::to_string(receipt_id));
    
    handler->sendFrameAscii(frame.toString(), '\0');
    // Don't set shouldTerminate yet - wait for RECEIPT
}
```

**Critical:** MUST include receipt header per PDF requirements

---

### Server Frame Handlers

#### **handleConnected (CONNECTED frame)**

**Implementation:**
```cpp
if (command == "CONNECTED") {
    isConnected = true;
    std::cout << "Login successful" << std::endl;
    // Socket thread is already running at this point
}
```

**Note:** Both Guy and Yael just print success message

---

#### **handleMessage (MESSAGE frame)**

**Implementation:**
```cpp
if (command == "MESSAGE") {
    Frame frame = Frame::parse(frameStr);
    std::string body = frame.getBody();
    
    // Parse body to create Event object
    Event event(body);  // See STEP 3
    
    // Extract user from body
    std::string user = "";
    std::stringstream bodyStream(body);
    std::string line;
    while (std::getline(bodyStream, line)) {
        if (line.find("user: ") == 0) {
            user = line.substr(6);
            break;
        }
    }
    
    // Don't store our own messages (avoid duplicates)
    if (user == currentUserName) {
        return true;
    }
    
    // Extract game name from Event
    std::string game_name = event.get_team_a_name() + "_" + event.get_team_b_name();
    
    // Store event
    gameEvents[game_name][user].push_back(event);
    
    // Display notification
    std::cout << "Received message from " << user << " in channel " << game_name << std::endl;
    // Optional: print full body for debugging
}
```

**Best Practice from Yael:** Skip storing our own messages (already stored in report)

---

#### **handleReceipt (RECEIPT frame)**

**Implementation:**
```cpp
if (command == "RECEIPT") {
    Frame frame = Frame::parse(frameStr);
    int id = std::stoi(frame.getHeader("receipt-id"));
    
    if (receiptActions.find(id) != receiptActions.end()) {
        std::string action = receiptActions[id];
        
        // Special handling for disconnect
        if (action == "DISCONNECT") {
            std::cout << "Disconnected properly." << std::endl;
            close();  // Sets shouldTerminate and isConnected
            return false;  // Signal thread to exit
        }
        
        // Print confirmation
        std::cout << action << std::endl;
        receiptActions.erase(id);
    }
}
```

**Critical:** DISCONNECT receipt must close connection and exit

---

#### **handleError (ERROR frame)**

**Implementation:**
```cpp
if (command == "ERROR") {
    Frame frame = Frame::parse(frameStr);
    std::string message = frame.getHeader("message");
    std::string body = frame.getBody();
    
    std::cout << "Received Error: " << message << std::endl;
    if (!body.empty()) {
        std::cout << body << std::endl;
    }
    
    close();  // Sets shouldTerminate and isConnected
    return false;  // Signal thread to exit
}
```

**Per PDF:** ERROR frame always closes connection

---

**Completion Criteria:**
✅ All 6 command handlers implemented  
✅ All 4 server frame handlers implemented  
✅ Subscription validation working  
✅ Receipt tracking functional  
✅ Event storage structure correct  

---

## STEP 3: Event Body Parser

**File:** [client/src/event.cpp](../../client/src/event.cpp) - **EXISTS, NEEDS IMPLEMENTATION**  
**File:** [client/include/event.h](../../client/include/event.h) - **EXISTS, COMPLETE**

### Purpose
Parse MESSAGE frame body back into Event object for storage and summary generation.

**Current State:**
- ✅ event.h already declares `Event(const std::string& frameBody)` constructor
- ✅ parseEventsFile() function is complete and working
- ✅ All getter methods are implemented
- ❌ Event(const std::string& frameBody) constructor is empty - needs implementation

### Implementation Required
The constructor exists at line 65 of event.cpp but is empty:
```cpp
Event::Event(const std::string &frame_body) : team_a_name(""), team_b_name(""), name(""), time(0), game_updates(), team_a_updates(), team_b_updates(), description("")
{
    // EMPTY - needs implementation
}
```

### Implementation (Based on Yael's approach)
```cpp
Event::Event(const std::string& frameBody) 
    : team_a_name(""), team_b_name(""), name(""), time(0), 
      game_updates(), team_a_updates(), team_b_updates(), description("")
{
    std::stringstream bodyStream(frameBody);
    std::string line;
    std::string current_section = "";
    
    while (std::getline(bodyStream, line)) {
        // Skip empty lines
        if (line.empty()) continue;
        
        // Parse main fields
        if (line.find("user: ") == 0) {
            // Skip user field (we extract it separately)
        }
        else if (line.find("team a: ") == 0) {
            team_a_name = line.substr(8);
        }
        else if (line.find("team b: ") == 0) {
            team_b_name = line.substr(8);
        }
        else if (line.find("event name: ") == 0) {
            name = line.substr(12);
        }
        else if (line.find("time: ") == 0) {
            time = std::stoi(line.substr(6));
        }
        // Section headers
        else if (line == "general game updates:") {
            current_section = "general";
        }
        else if (line == "team a updates:") {
            current_section = "team_a";
        }
        else if (line == "team b updates:") {
            current_section = "team_b";
        }
        else if (line == "description:") {
            current_section = "description";
            // Read rest as description
            std::string desc_line;
            while (std::getline(bodyStream, desc_line)) {
                if (!description.empty()) description += "\n";
                description += desc_line;
            }
            break;
        }
        // Parse key:value pairs for updates
        else if (!current_section.empty() && current_section != "description") {
            size_t colon = line.find(':');
            if (colon != std::string::npos) {
                std::string key = line.substr(0, colon);
                std::string value = line.substr(colon + 1);
                
                if (current_section == "general") {
                    game_updates[key] = value;
                }
                else if (current_section == "team_a") {
                    team_a_updates[key] = value;
                }
                else if (current_section == "team_b") {
                    team_b_updates[key] = value;
                }
            }
        }
    }
}
```

### Key Parsing Logic

**Section Tracking:** Use `current_section` string to track which section we're in:
- "general" → parse into `game_updates`
- "team_a" → parse into `team_a_updates`
- "team_b" → parse into `team_b_updates`
- "description" → read all remaining lines

**Key:Value Parsing:**
```cpp
size_t colon = line.find(':');
std::string key = line.substr(0, colon);
std::string value = line.substr(colon + 1);
```

**Multi-line Description:** Read until end of stream

### Best Practice from Yael
✅ Skip empty lines  
✅ Use section state machine  
✅ Handle multi-line description correctly  
✅ Preserve newlines in description  

**Completion Criteria:**
✅ Event constructor parses all fields correctly   - **EXISTS, NEARLY EMPTY**

### Purpose
Coordinate two threads for simultaneous keyboard and socket I/O. Main thread handles user input, socket thread handles server messages.

**Current State:** File exists with only:
```cpp
int main(int argc, char *argv[]) {
	// TODO: implement the STOMP client
	return 0;
}
```
Need to implement complete two-threaded architecture

---

## STEP 4: Two-Threaded Main Program

**File:** [client/src/StompClient.cpp](../../client/src/StompClient.cpp)

### Purpose
Coordinate two threads for simultaneous keyboard and socket I/O. Main thread handles user input, socket thread handles server messages.

### Implementation (Based on Yael's simpler approach)

```cpp
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
            
            // Blocking read from socket
            if (!connectionHandler.getFrameAscii(answer, '\0')) {
                std::cout << "Disconnected from server." << std::endl;
                protocol.close();
                break;
            }
            
            // Process server frame
            bool shouldContinue = protocol.processServerFrame(answer);
            if (!shouldContinue) {
                break;  // Exit on logout or error
            }
        }
    });
    
    // Main thread: keyboard input
    while (true) {
        const short bufsize = 1024;
        char buf[bufsize];
        std::cin.getline(buf, bufsize);
        std::string line(buf);
        
        protocol.processKeyboardCommand(line);
        
        // Check if we should exit
        if (protocol.shouldLogout()) {
            break;
        }
    }
    
    // Wait for socket thread to finish
    socketThread.join();
    
    return 0;
}
```

### Key Architecture Decisions

**Guy vs Yael Comparison:**

| Aspect | Guy | Yael | Our Choice |
|--------|-----|------|------------|
| **Connection** | Created in login command | Created in main() | **Yael** (simpler, connection always ready) |
| **Thread Start** | After CONNECTED | Immediately in main() | **Yael** (simpler, thread always runs) |
| **Global Variables** | Yes (isLoggedIn, etc.) | No (all in protocol) | **Yael** (cleaner encapsulation) |
| **Thread Join** | Detach | Join | **Yael** (proper cleanup) |
| **Mutex** | No | Yes | **Yael** (thread-safe) |

**Why Yael's Approach is Better:**
1. ✅ **Simpler initialization:** Connection established in main(), no special login handling
2. ✅ **No global state:** Everything encapsulated in StompProtocol class
3. ✅ **Thread safety:** Uses mutex for shared state protection
4. ✅ **Proper cleanup:** Joins thread before exit
5. ✅ **Less code:** Fewer lines, easier to understand

**Command-line Arguments:** `./StompWCIClient host port`
- User types `login host:port username password` to authenticate
- Connection already established, just send CONNECT frame

### Thread Coordination

**Shared State Protection (Yael's improvement):**
```cpp
// In StompProtocol.h
private:
    std::mutex mtx;

// In critical sections:
void someMethod() {
    std::lock_guard<std::mutex> lock(mtx);
    // Access shared data safely
}
```

**Exit Coordination:**
- Socket thread checks `protocol.processServerFrame()` return value
- Main thread checks `protocol.shouldLogout()`
- Both threads exit when `shouldTerminate` is true

**Completion Criteria:**
✅ Main thread reads keyboard, sends commands  
✅ Socket thread reads socket, displays messages   - **EXISTS, NEEDS UPDATES**

### Current State
```makefile
CFLAGS:=-c -Wall -Weffc++ -g -std=c++11 -Iinclude
LDFLAGS:=-lboost_system -lpthread

all: EchoClient

EchoClient: bin/ConnectionHandler.o bin/echoClient.o
	g++ -o bin/EchoClient bin/ConnectionHandler.o bin/echoClient.o $(LDFLAGS)

StompWCIClient: bin/ConnectionHandler.o bin/StompClient.obin/event.o  # TYPO: missing space!
	g++ -o bin/StompWCIClient bin/ConnectionHandler.o bin/StompClient.o $(LDFLAGS)
```

### Issues Found
1. ❌ `all:` target builds EchoClient instead of StompWCIClient
2. ❌ StompWCIClient target has typo: `bin/StompClient.obin/event.o` (missing space)
3. ❌ Missing Frame.o dependency
4. ❌ Missing StompProtocol.o dependency
5. ✅ pthread flag already present (-lpthread)

### Required Changes

Update makefile to:
1. Change `all:` target to StompWCIClient
2. Fix typo in StompWCIClient dependencies
3. Add Frame.o and StompProtocol.o dependencies
4. Add build rules for Frame.o and StompProtocol.o

```makefile
CFLAGS:=-c -Wall -Weffc++ -g -std=c++11 -Iinclude
LDFLAGS:=-lboost_system -lpthread

all: StompWCIClient

EchoClient: bin/ConnectionHandler.o bin/echoClient.o
	g++ -o bin/EchoClient bin/ConnectionHandler.o bin/echoClient.o $(LDFLAGS)

StompWCIClient: bin/ConnectionHandler.o bin/StompClient.o bin/StompProtocol.o bin/Frame.o bin/event.o
	g++ -o bin/StompWCIClient bin/ConnectionHandler.o bin/StompClient.o bin/StompProtocol.o bin/Frame.o bin/event.o $(LDFLAGS)

bin/ConnectionHandler.o: src/ConnectionHandler.cpp
	g++ $(CFLAGS) -o bin/ConnectionHandler.o src/ConnectionHandler.cpp

bin/echoClient.o: src/echoClient.cpp
	g++ $(CFLAGS) -o bin/echoClient.o src/echoClient
LDFLAGS:=-lboost_system -pthread

all: StompWCIClient

StompWCIClient: bin/ConnectionHandler.o bin/StompClient.o bin/StompProtocol.o bin/Frame.o bin/event.o
	g++ -o bin/StompWCIClient bin/ConnectionHandler.o bin/StompClient.o bin/StompProtocol.o bin/Frame.o bin/event.o $(LDFLAGS)

bin/ConnectionHandler.o: src/ConnectionHandler.cpp
	g++ $(CFLAGS) -o bin/ConnectionHandler.o src/ConnectionHandler.cpp

bin/StompClient.o: src/StompClient.cpp
	g++ $(CFLAGS) -o bin/StompClient.o src/StompClient.cpp

bin/StompProtocol.o: src/StompProtocol.cpp
	g++ $(CFLAGS) -o bin/StompProtocol.o src/StompProtocol.cpp

bin/Frame.o: src/Frame.cpp
	g++ $(CFLAGS) -o bin/Frame.o src/Frame.cpp

bin/event.o: src/event.cpp
	g++ $(CFLAGS) -o bin/event.o src/event.cpp

.PHONY: clean
clean:
	rm -f bin/*
```

**Completion Criteria:**
✅ `make` compiles without errors  
✅ Executable named `StompWCIClient` in bin/  
✅ All dependencies linked correctly  
✅ `make clean` works  

---

## STEP 6: Integration Testing

### Test Scenarios

#### **Test 1: Login Flow**
```bash
./bin/StompWCIClient 127.0.0.1 7777
> login 127.0.0.1:7777 moshiko 12345678
Login successful
```

**Expected:** CONNECTED received, can now use other commands

---

#### **Test 2: Join/Exit with Receipts**
```bash
> join germany_japan
Joined channel germany_japan

> exit germany_japan
Exited channel germany_japan
```

**Expected:** RECEIPT frames confirm actions

---

#### **Test 3: Report Events**
```bash
> join germany_japan
Joined channel germany_japan

> report ../data/events1.json
[Multiple SEND frames sent]
```

**Expected:** No errors, events sent to channel

---

#### **Test 4: Receive Messages (Multi-Client)**

**Client A:**
```bash
> login 127.0.0.1:7777 alice password
Login successful
> join germany_japan
Joined channel germany_japan
```

**Client B:**
```bash
> login 127.0.0.1:7777 bob password
Login successful
> join germany_japan
Joined channel germany_japan
> report ../data/events1.json
```

**Client A Expected:** Receives MESSAGE frames from bob in real-time while waiting for keyboard input

---

#### **Test 5: Summary Generation**
```bash
> summary germany_japan bob ../summary_output.txt
Summary written to ../summary_output.txt
```

**Verify:** File exists with correct format from PDF page 14

---

#### **Test 6: Logout**
```bash
> logout
Disconnected properly.
[Client exits]
```

**Expected:** RECEIPT received, clean exit

---

#### **Test 7: Error Handling**
```bash
> login 127.0.0.1:7777 wronguser wrongpass
Received Error: Wrong password
[Connection closed]
```

**Expected:** ERROR frame displayed, connection closed

---

#### **Test 8: Two-Thread Verification**

**Key Test:** Verify main thread can read keyboard while socket thread receives messages

**Setup:**
1. Client A joins channel
2. Client B sends many events with delays
3. While Client A receives MESSAGE frames, type commands

**Expected:** Client A can type and execute commands while receiving messages concurrently

---

## Best Practices Summary

### ✅ Keep from Guy's Implementation
- Modular Frame class with parse/toString
- Receipt action mapping for good UX
- Event storage structure (game → user → events)
- Two-thread architecture separation
**CREATE** Frame.h with all methods declared
- [ ] **CREATE** Frame.cpp with toString() implementation
- [ ] **CREATE**nection in main() instead of login command (simpler)
- Mutex protection for shared state (thread-safe)
- Thread join instead of detach (proper cleanup)
- Validate subscriptions before operations
- Skip storing our own messages (avoid duplicates)
- Inli**UPDATE** StompProtocol.h with complete class definition (currently empty)
- [ ] **CREATE** StompProtocol.cpp implementation file
- [ ] Helper method: split()
- [ ] Command: login
- [ ] Command: join
- [ ] Command: exit
- [ ] Command: report (use existing parseEventsFile function) explaining logic
- Consistent naming conventions

### ❌ Avoid These Pitfalls
- ❌ Starting socket thread after CONNECTED (unnecessary complexity)
- ❌ Global variables for coordination (use class members)
- ❌ Thread detach without join (resource leaks)
- ❌ No mutex for shared state (race conditions)
- ❌ Complex event sorting (YAGNI - You Ain't Gonna Need It)
- ❌ Forgetting null terminator (ConnectionHandler handles it)

---

## Implementation Checklist

### Step 1: Frame Class
- [ ] Frame.h with all methods declared
- [ ] Frame.cpp with toString() implementation
- [ ] Frame.cpp with parse() implementation
- [ ] Test frame creation and parsing
- [ ] Verify edge cases (no body, no headers)

### Step 2: StompProtocol
- [ ] StompProtocol.h with class definition
- [ ] Helper method: split()
- [ ] Command: login
- [ ] Command: join
- [ ] Command: exit
- [ ] Command: report
- [ ] Command: summary
- [ ] Command: logout
- [ ] Server frame: CONNECTED
- [ ] Server frame: MESSAGE
- [ ] Server frame: RECEIPT
- [ ] Server frame: ERROR
- [ ] State management (shouldTerminate, isConnected)
- [ ] Mutex protection for shared data

### St**IMPLEMENT** Event(string) constructor body in event.cpp (line 65 - currently empty)
- [ ] Parse main fields (team names, event name, time)
- [ ] Parse general game updates
- [ ] Parse team a updates
- [ ] Parse team b updates
- [ ] Parse multi-line description
- [ ] Test with sample MESSAGE body
- [ ] Note: All other Event methods are already implemented ✅
- [ ] Test with sample MESSAGE body
**REPLACE** stub in StompClient.cpp with full implementation
- [ ] Command-line argument parsing (argc, argv)
- [ ] ConnectionHandler initialization (already exists, can use directly)
- [ ] StompProtocol initialization
- [ ] Socket listener thread lambda
- [ ] Main thread keyboard loop
- [ ] Thread join on exit
- [ ] Error handling
- [ ] Note: ConnectionHandler is fully implemented and ready to use ✅yboard loop
- [ ] **FIX** `all:` target (currently builds EchoClient, should build StompWCIClient)
- [ ] **FIX** typo in StompWCIClient line: `bin/StompClient.obin/event.o` → add space
- [ ] **ADD** Frame.o dependency
- [ ] **ADD** StompProtocol.o dependency
- [ ] **ADD** build rules for Frame.o and StompProtocol.o
- [ ] Test make clean
- [ ] Test make all (should produce StompWCIClient)
- [ ] Note: pthread flag (-lpthread) already present ✅ocol.o dependency
- [ ] Add StompClient.o dependency
- [ ] Ensure pthread flag
- [ ] Test make clean
- [ ] Test make all

### Step 6: Testing
- [ ] Test login success
- [ ] Test login failure (wrong password)
- [ ] Test join/exit with receipts
- [ ] Test report command
- [ ] Test multi-client message exchange
- [ ] Test summary generation
- [ ] Test logout
- [ ] Test two-thread concurrency
- [ ] Test error scenarios
- [ ] Verify no memory leaks (valgrind)
- [ ] Verify no race conditions (helgrind)

---

## Next Steps After Implementation

1. **Comprehensive Testing:** Test all 6 commands with actual server
2. **Multi-Client Testing:** Run 10+ clients simultaneously
3. **Edge Cases:** Empty files, malformed JSON, network delays
4. **Performance:** Large event files (1000+ events)
5. **Thread Safety:** Run with helgrind to verify no race conditions
6. **Memory Safety:** Run with valgrind to verify no leaks
7. **Output Format:** Verify summary matches PDF page 14 exactly

---

## Reference Implementation Comparison

| Feature | Guy | Yael | Our Plan |
|---------|-----|------|----------|
| **Frame Class** | ✅ Separate class | ❌ Inline parsing | ✅ Separate (modular) |
| **Connection** | In login cmd | In main() | ✅ In main() (simpler) |
| **Thread Safety** | ❌ No mutex | ✅ Mutex | ✅ Mutex |
| **Thread Join** | ❌ Detach | ✅ Join | ✅ Join |
| **Subscription Check** | ❌ No validation | ❌ No validation | ✅ Validate (safer) |
| **Event Sorting** | ❌ Not mentioned | ✅ Halftime logic | ❌ File order (simpler) |
| **Own Message Skip** | ❌ Not shown | ✅ Skip duplicates | ✅ Skip (efficient) |
| **Error Messages** | ✅ Good | ✅ Good | ✅ Consistent |

**Our approach:** Take best of both worlds, add improvements where needed
