CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra -g -pthread
INCLUDES = -I../client/include

# Object files from client
CLIENT_SRC = ../client/src
CONN_HANDLER = $(CLIENT_SRC)/ConnectionHandler.cpp

# Test executables
TEST_FRAME = test_frame_format
TEST_EVENT = test_event_parsing
TEST_INTEGRATION = test_full_integration

.PHONY: all clean test unit-test integration-test full-test help

all: $(TEST_FRAME) $(TEST_EVENT) $(TEST_INTEGRATION)

# Build object files from client source
Frame.o: $(CLIENT_SRC)/Frame.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $(CLIENT_SRC)/Frame.cpp -o Frame.o

event.o: $(CLIENT_SRC)/event.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $(CLIENT_SRC)/event.cpp -o event.o

ConnectionHandler.o: $(CONN_HANDLER)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $(CONN_HANDLER) -o ConnectionHandler.o

# Build test executables
$(TEST_FRAME): test_frame_format.cpp Frame.o
	$(CXX) $(CXXFLAGS) $(INCLUDES) test_frame_format.cpp Frame.o -o $(TEST_FRAME)

$(TEST_EVENT): test_event_parsing.cpp event.o
	$(CXX) $(CXXFLAGS) $(INCLUDES) test_event_parsing.cpp event.o -o $(TEST_EVENT)

$(TEST_INTEGRATION): test_full_integration.cpp ConnectionHandler.o Frame.o
	$(CXX) $(CXXFLAGS) $(INCLUDES) test_full_integration.cpp ConnectionHandler.o Frame.o -o $(TEST_INTEGRATION) -lboost_system

# Run unit tests only (no server needed)
unit-test: $(TEST_FRAME) $(TEST_EVENT)
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  UNIT TESTS (No server required)"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "Running Frame Format Tests..."
	@./$(TEST_FRAME)
	@echo ""
	@echo "Running Event Parsing Tests..."
	@./$(TEST_EVENT)
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  ✅ UNIT TESTS COMPLETED"
	@echo "════════════════════════════════════════════════════════"

# Run integration tests (requires server)
integration-test: $(TEST_INTEGRATION)
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  INTEGRATION TESTS (Requires server running)"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@./$(TEST_INTEGRATION)

# Run client command tests (shell script)
client-test:
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  CLIENT COMMAND TESTS"
	@echo "════════════════════════════════════════════════════════"
	@./test_client_commands.sh

# Run server stress test (shell script)
stress-test:
	@echo ""
	@echo "════════════════════════════════════════════════════════"
	@echo "  SERVER STRESS TEST"
	@echo "════════════════════════════════════════════════════════"
	@./test_server_stress.sh

# Run ALL tests (unit + integration + client + stress)
full-test: unit-test integration-test client-test stress-test
	@echo ""
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║  ✅ ALL TEST SUITES COMPLETED SUCCESSFULLY             ║"
	@echo "╚════════════════════════════════════════════════════════╝"

# Quick test - just unit tests
test: unit-test

clean:
	rm -f *.o $(TEST_FRAME) $(TEST_EVENT) $(TEST_INTEGRATION)
	rm -f test_*.input test_*.output test_*.log
	rm -f stress_client_*.input stress_client_*.log

help:
	@echo "Available targets:"
	@echo "  make              - Build all test executables"
	@echo "  make test         - Run unit tests only (no server needed)"
	@echo "  make unit-test    - Run unit tests (Frame & Event parsing)"
	@echo "  make integration-test - Run integration tests (needs server)"
	@echo "  make client-test  - Test all client commands"
	@echo "  make stress-test  - Test concurrent clients (stress test)"
	@echo "  make full-test    - Run ALL tests (comprehensive)"
	@echo "  make clean        - Clean all build artifacts"
	@echo ""
	@echo "Server must be running for integration/client/stress tests:"
	@echo "  cd ../server"
	@echo "  mvn exec:java -Dexec.mainClass=\"bgu.spl.net.impl.stomp.StompServer\" -Dexec.args=\"7777\""
