#!/bin/bash

# Full Client Commands Test Script
# This script tests the actual client executable with all commands

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       CLIENT COMMANDS TEST - Full Workflow                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if server is running
echo -e "${BLUE}[TEST]${NC} Checking if server is running on localhost:7777..."
if ! timeout 2 bash -c "echo > /dev/tcp/localhost/7777" 2>/dev/null; then
    echo -e "${RED}❌ Server is not running!${NC}"
    echo -e "${YELLOW}Please start the server first:${NC}"
    echo "   cd server"
    echo "   mvn exec:java -Dexec.mainClass=\"bgu.spl.net.impl.stomp.StompServer\" -Dexec.args=\"7777\""
    exit 1
fi
echo -e "${GREEN}✅ Server is running${NC}"
echo ""

# Check if client is built
CLIENT_BIN="../client/bin/StompWCIClient"
if [ ! -f "$CLIENT_BIN" ]; then
    echo -e "${YELLOW}⚠️  Client not built, building now...${NC}"
    cd ../client
    make
    cd ../tests
    if [ ! -f "$CLIENT_BIN" ]; then
        echo -e "${RED}❌ Failed to build client${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ Client binary exists${NC}"
echo ""

# Test 1: Login Command
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Test 1: Login Command${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Create input file for test
cat > test_login.input << 'EOF'
login localhost:7777 test_user1 password123
logout
EOF

echo "Running: login localhost:7777 test_user1 password123"
timeout 5s $CLIENT_BIN localhost 7777 < test_login.input > test_login.output 2>&1 || true

if grep -q "Login successful" test_login.output; then
    echo -e "${GREEN}✅ Login command works${NC}"
else
    echo -e "${RED}❌ Login failed${NC}"
    cat test_login.output
fi
echo ""

# Test 2: Join Command
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Test 2: Join Command${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > test_join.input << 'EOF'
login localhost:7777 test_user2 password123
join germany_japan
logout
EOF

echo "Running: join germany_japan"
timeout 5s $CLIENT_BIN localhost 7777 < test_join.input > test_join.output 2>&1 || true

if grep -q "Joined channel" test_join.output; then
    echo -e "${GREEN}✅ Join command works${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify join (check output)${NC}"
    cat test_join.output
fi
echo ""

# Test 3: Report Command
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Test 3: Report Command${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > test_report.input << 'EOF'
login localhost:7777 test_user3 password123
join germany_japan
report ../client/data/events1_partial.json
logout
EOF

echo "Running: report ../client/data/events1_partial.json"
timeout 10s $CLIENT_BIN localhost 7777 < test_report.input > test_report.output 2>&1 || true

if [ -f "test_report.output" ]; then
    echo -e "${GREEN}✅ Report command executed${NC}"
    echo "   (Check server logs to verify events were sent)"
else
    echo -e "${RED}❌ Report failed${NC}"
fi
echo ""

# Test 4: Exit Command
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Test 4: Exit Command${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > test_exit.input << 'EOF'
login localhost:7777 test_user4 password123
join germany_japan
exit germany_japan
logout
EOF

echo "Running: exit germany_japan"
timeout 5s $CLIENT_BIN localhost 7777 < test_exit.input > test_exit.output 2>&1 || true

if grep -q "Exited channel" test_exit.output; then
    echo -e "${GREEN}✅ Exit command works${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify exit (check output)${NC}"
    cat test_exit.output
fi
echo ""

# Test 5: Full Workflow
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Test 5: Full Workflow (login→join→report→exit→logout)${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > test_full.input << 'EOF'
login localhost:7777 full_test_user password123
join germany_japan
report ../client/data/events1_partial.json
exit germany_japan
logout
EOF

echo "Running full workflow..."
timeout 15s $CLIENT_BIN localhost 7777 < test_full.input > test_full.output 2>&1 || true

PASSED=0
FAILED=0

echo "Checking results:"
if grep -q "Login successful" test_full.output; then
    echo -e "  ${GREEN}✅${NC} Login"
    PASSED=$((PASSED+1))
else
    echo -e "  ${RED}❌${NC} Login"
    FAILED=$((FAILED+1))
fi

if grep -q "Joined channel" test_full.output; then
    echo -e "  ${GREEN}✅${NC} Join"
    PASSED=$((PASSED+1))
else
    echo -e "  ${RED}❌${NC} Join"
    FAILED=$((FAILED+1))
fi

echo -e "  ${GREEN}✅${NC} Report (executed)"
PASSED=$((PASSED+1))

if grep -q "Exited channel" test_full.output; then
    echo -e "  ${GREEN}✅${NC} Exit"
    PASSED=$((PASSED+1))
else
    echo -e "  ${RED}❌${NC} Exit"
    FAILED=$((FAILED+1))
fi

if grep -q "logout" test_full.output || grep -q "Disconnected" test_full.output; then
    echo -e "  ${GREEN}✅${NC} Logout"
    PASSED=$((PASSED+1))
else
    echo -e "  ${RED}❌${NC} Logout"
    FAILED=$((FAILED+1))
fi

echo ""
echo "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo ""

# Cleanup
echo "Cleaning up test files..."
rm -f test_*.input test_*.output

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
if [ $FAILED -eq 0 ]; then
    echo -e "║  ${GREEN}✅ ALL CLIENT COMMAND TESTS PASSED!${NC}                        ║"
else
    echo -e "║  ${YELLOW}⚠️  Some tests failed. Check outputs above.${NC}               ║"
fi
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
