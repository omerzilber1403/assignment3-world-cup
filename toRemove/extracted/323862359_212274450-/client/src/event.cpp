#include "../include/event.h"
#include "../include/json.hpp"
#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <vector>
#include <sstream>
using json = nlohmann::json;

Event::Event(std::string team_a_name, std::string team_b_name, std::string name, int time,
             std::map<std::string, std::string> game_updates, std::map<std::string, std::string> team_a_updates,
             std::map<std::string, std::string> team_b_updates, std::string discription)
    : team_a_name(team_a_name), team_b_name(team_b_name), name(name),
      time(time), game_updates(game_updates), team_a_updates(team_a_updates),
      team_b_updates(team_b_updates), description(discription)
{
}

Event::~Event()
{
}

const std::string &Event::get_team_a_name() const
{
    return this->team_a_name;
}

const std::string &Event::get_team_b_name() const
{
    return this->team_b_name;
}

const std::string &Event::get_name() const
{
    return this->name;
}

int Event::get_time() const
{
    return this->time;
}

const std::map<std::string, std::string> &Event::get_game_updates() const
{
    return this->game_updates;
}

const std::map<std::string, std::string> &Event::get_team_a_updates() const
{
    return this->team_a_updates;
}

const std::map<std::string, std::string> &Event::get_team_b_updates() const
{
    return this->team_b_updates;
}

const std::string &Event::get_discription() const
{
    return this->description;
}

Event::Event(const std::string &frame_body) : team_a_name(""), team_b_name(""), name(""), time(0), game_updates(), team_a_updates(), team_b_updates(), description("")
{
    std::istringstream input_stream(frame_body);
    std::string current_line;
    
    enum class ParseState { NONE, GENERAL_UPDATES, TEAM_A_UPDATES, TEAM_B_UPDATES, DESCRIPTION };
    ParseState state = ParseState::NONE;
    
    while (std::getline(input_stream, current_line)) {
        if (current_line.empty()) continue;
        
        // Parse field: value format
        size_t separator_pos = current_line.find(": ");
        if (separator_pos != std::string::npos && state == ParseState::NONE) {
            std::string field = current_line.substr(0, separator_pos);
            std::string value = current_line.substr(separator_pos + 2);
            
            if (field == "user") {
                continue; // Skip user field
            } else if (field == "team a") {
                team_a_name = value;
            } else if (field == "team b") {
                team_b_name = value;
            } else if (field == "event name") {
                name = value;
            } else if (field == "time") {
                time = std::stoi(value);
            }
            continue;
        }
        
        // Check for section transitions
        if (current_line == "general game updates:") {
            state = ParseState::GENERAL_UPDATES;
        } else if (current_line == "team a updates:") {
            state = ParseState::TEAM_A_UPDATES;
        } else if (current_line == "team b updates:") {
            state = ParseState::TEAM_B_UPDATES;
        } else if (current_line == "description:") {
            state = ParseState::DESCRIPTION;
            // Collect remaining lines as description
            std::string remaining_line;
            while (std::getline(input_stream, remaining_line)) {
                description += remaining_line + "\n";
            }
            // Remove trailing newline
            if (!description.empty() && description.back() == '\n') {
                description.pop_back();
            }
        } else if (state != ParseState::NONE && state != ParseState::DESCRIPTION) {
            // Parse key:value in update sections
            size_t separator_pos = current_line.find(':');
            if (separator_pos != std::string::npos) {
                std::string update_key = current_line.substr(0, separator_pos);
                std::string update_value = current_line.substr(separator_pos + 1);
                
                switch (state) {
                    case ParseState::GENERAL_UPDATES:
                        game_updates[update_key] = update_value;
                        break;
                    case ParseState::TEAM_A_UPDATES:
                        team_a_updates[update_key] = update_value;
                        break;
                    case ParseState::TEAM_B_UPDATES:
                        team_b_updates[update_key] = update_value;
                        break;
                    default:
                        break;
                }
            }
        }
    }
}

names_and_events parseEventsFile(std::string json_path)
{
    std::ifstream f(json_path);
    json data = json::parse(f);

    std::string team_a_name = data["team a"];
    std::string team_b_name = data["team b"];

    // run over all the events and convert them to Event objects
    std::vector<Event> events;
    for (auto &event : data["events"])
    {
        std::string name = event["event name"];
        int time = event["time"];
        std::string description = event["description"];
        std::map<std::string, std::string> game_updates;
        std::map<std::string, std::string> team_a_updates;
        std::map<std::string, std::string> team_b_updates;
        for (auto &update : event["general game updates"].items())
        {
            if (update.value().is_string())
                game_updates[update.key()] = update.value();
            else
                game_updates[update.key()] = update.value().dump();
        }

        for (auto &update : event["team a updates"].items())
        {
            if (update.value().is_string())
                team_a_updates[update.key()] = update.value();
            else
                team_a_updates[update.key()] = update.value().dump();
        }

        for (auto &update : event["team b updates"].items())
        {
            if (update.value().is_string())
                team_b_updates[update.key()] = update.value();
            else
                team_b_updates[update.key()] = update.value().dump();
        }
        
        events.push_back(Event(team_a_name, team_b_name, name, time, game_updates, team_a_updates, team_b_updates, description));
    }
    names_and_events events_and_names{team_a_name, team_b_name, events};

    return events_and_names;
}