#pragma once
#include <string>
#include <map>

class Frame {
private:
    std::string command;
    std::map<std::string, std::string> headers;
    std::string body;

public:
    Frame(std::string command);
    Frame();
    
    // Getters/Setters
    std::string getCommand() const;
    void addHeader(const std::string& key, const std::string& val);
    std::string getHeader(const std::string& key) const;
    bool hasHeader(const std::string& key) const;
    std::map<std::string, std::string> getHeaders() const;
    std::string getBody() const;
    void setBody(const std::string& body);
    
    // Conversion methods
    std::string toString() const;
    static Frame parse(const std::string& msg);
};
