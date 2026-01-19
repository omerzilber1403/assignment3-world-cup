#include <iostream>
#include <cassert>
#include "../client/include/event.h"

void testJSONParsing() {
    std::cout << "\n=== Test: JSON Event Parsing ===" << std::endl;
    
    // Test with the actual events file
    try {
        names_and_events result = parseEventsFile("../client/data/events1_partial.json");
        
        std::cout << "✅ Team A: " << result.team_a_name << std::endl;
        std::cout << "✅ Team B: " << result.team_b_name << std::endl;
        std::cout << "✅ Number of events: " << result.events.size() << std::endl;
        
        if (result.events.empty()) {
            std::cerr << "❌ FAILED: No events parsed from file" << std::endl;
            exit(1);
        }
        
        const Event& firstEvent = result.events[0];
        std::cout << "✅ First event name: " << firstEvent.get_name() << std::endl;
        std::cout << "✅ First event time: " << firstEvent.get_time() << std::endl;
        
        // Check game updates exist
        const auto& gameUpdates = firstEvent.get_game_updates();
        if (gameUpdates.empty()) {
            std::cerr << "⚠️  WARNING: No game updates in first event" << std::endl;
        } else {
            std::cout << "✅ Game updates found: " << gameUpdates.size() << " items" << std::endl;
        }
        
        std::cout << "✅ PASSED: JSON parsing works correctly" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "❌ FAILED: " << e.what() << std::endl;
        exit(1);
    }
}

void testEventConstructorFromFrameBody() {
    std::cout << "\n=== Test: Event Construction from Frame Body ===" << std::endl;
    
    std::string frameBody = 
        "user: john\n"
        "team a: USA\n"
        "team b: Mexico\n"
        "event name: Goal scored\n"
        "time: 45\n"
        "general game updates:\n"
        "score:2-1\n"
        "possession:55\n"
        "team a updates:\n"
        "goals:2\n"
        "shots:10\n"
        "team b updates:\n"
        "goals:1\n"
        "shots:8\n"
        "description:\n"
        "USA scores a goal in the 45th minute!";
    
    Event event(frameBody);
    
    assert(event.get_team_a_name() == "USA");
    std::cout << "✅ Team A parsed: " << event.get_team_a_name() << std::endl;
    
    assert(event.get_team_b_name() == "Mexico");
    std::cout << "✅ Team B parsed: " << event.get_team_b_name() << std::endl;
    
    assert(event.get_name() == "Goal scored");
    std::cout << "✅ Event name parsed: " << event.get_name() << std::endl;
    
    assert(event.get_time() == 45);
    std::cout << "✅ Time parsed: " << event.get_time() << std::endl;
    
    const auto& gameUpdates = event.get_game_updates();
    assert(gameUpdates.find("score") != gameUpdates.end());
    std::cout << "✅ Game updates parsed (score: " << gameUpdates.at("score") << ")" << std::endl;
    
    const auto& teamAUpdates = event.get_team_a_updates();
    assert(teamAUpdates.find("goals") != teamAUpdates.end());
    std::cout << "✅ Team A updates parsed (goals: " << teamAUpdates.at("goals") << ")" << std::endl;
    
    const std::string& desc = event.get_discription();
    assert(desc.find("45th minute") != std::string::npos);
    std::cout << "✅ Description parsed correctly" << std::endl;
    
    std::cout << "✅ PASSED: Event parsing from frame body works!" << std::endl;
}

int main() {
    std::cout << "╔═══════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║  Event Parsing Tests                                 ║" << std::endl;
    std::cout << "╚═══════════════════════════════════════════════════════╝" << std::endl;
    
    try {
        testJSONParsing();
        testEventConstructorFromFrameBody();
        
        std::cout << "\n╔═══════════════════════════════════════════════════════╗" << std::endl;
        std::cout << "║  ✅ ALL EVENT TESTS PASSED!                          ║" << std::endl;
        std::cout << "╚═══════════════════════════════════════════════════════╝" << std::endl;
        
        return 0;
        
    } catch (const std::exception& e) {
        std::cerr << "\n❌ Test suite failed: " << e.what() << std::endl;
        return 1;
    }
}
