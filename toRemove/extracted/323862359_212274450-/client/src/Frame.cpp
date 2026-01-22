#include "../include/Frame.h"
#include <sstream>

Frame::Frame(std::string cmd) : command(cmd), headers(), body("") {}

Frame::Frame() : command(""), headers(), body("") {}

std::string Frame::getCommand() const {
    return command;
}

void Frame::addHeader(const std::string& key, const std::string& val) {
    headers[key] = val;
}

std::string Frame::getHeader(const std::string& key) const {
    auto it = headers.find(key);
    if (it != headers.end()) {
        return it->second;
    }
    return "";
}

bool Frame::hasHeader(const std::string& key) const {
    return headers.find(key) != headers.end();
}

std::map<std::string, std::string> Frame::getHeaders() const {
    return headers;
}

std::string Frame::getBody() const {
    return body;
}

void Frame::setBody(const std::string& b) {
    body = b;
}

std::string Frame::toString() const {
    std::string result = command + "\n";
    
    for (const auto& kv : headers) {
        result += kv.first + ":" + kv.second + "\n";
    }
    
    result += "\n";
    
    if (!body.empty()) {
        result += body;
    }
    
    return result;
}

Frame Frame::parse(const std::string& msg) {
    Frame frame;
    std::stringstream stream(msg);
    std::string line;
    
    // First line is command
    if (std::getline(stream, line)) {
        frame.command = line;
    }
    
    // Parse headers until blank line
    while (std::getline(stream, line)) {
        if (line.empty()) {
            // Rest is body
            std::string bodyContent;
            char c;
            while (stream.get(c)) {
                bodyContent += c;
            }
            frame.body = bodyContent;
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
