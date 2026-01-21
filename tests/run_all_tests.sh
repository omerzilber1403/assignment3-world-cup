#!/bin/bash
# Master Test Runner - Runs all tests in sequence
# Use this to validate entire assignment before submission

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🚀 MASTER TEST RUNNER - Assignment 3 SPL                 ║"
echo "║  Complete validation of all assignment sections           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

WORKSPACE="/workspaces/Assignment 3 SPL"
cd "$WORKSPACE"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_RESULTS=()

run_test() {
    local test_name=$1
    local test_script=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}▶${NC}  Running: ${YELLOW}${test_name}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if bash "$test_script"; then
        echo -e "${GREEN}✅${NC} ${test_name} PASSED"
        TEST_RESULTS+=("PASS:$test_name")
    else
        echo -e "${RED}❌${NC} ${test_name} FAILED"
        TEST_RESULTS+=("FAIL:$test_name")
    fi
    
    sleep 2
}

# Make scripts executable
chmod +x tests/*.sh 2>/dev/null || true

echo ""
echo "Test execution order:"
echo "  1. Quick Smoke Test (30s) - Basic functionality"
echo "  2. SQL Integration Test (60s) - Database & safety requirements"
echo "  3. Full Integration Test (120s) - Complete workflows"
echo ""
read -p "Press ENTER to start testing..." 

# Run tests
run_test "Quick Smoke Test" "tests/quick_smoke_test.sh"
run_test "SQL Integration Test" "tests/sql_integration_test.sh"
run_test "Full Integration Test" "tests/full_integration_test.sh"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  📊 TEST SUMMARY                                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

TOTAL=0
PASSED=0
FAILED=0

for result in "${TEST_RESULTS[@]}"; do
    TOTAL=$((TOTAL + 1))
    if [[ $result == PASS:* ]]; then
        PASSED=$((PASSED + 1))
        echo -e "${GREEN}✅${NC} ${result#PASS:}"
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}❌${NC} ${result#FAIL:}"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Total: $TOTAL   Passed: ${GREEN}$PASSED${NC}   Failed: ${RED}$FAILED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🎉 ALL TESTS PASSED - Assignment ready for submission!   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ Section 3.1 (Client): Working"
    echo "✅ Section 3.2 (Server): Working"
    echo "✅ Section 3.3 (SQL): Working"
    echo "✅ All safety requirements validated"
    echo ""
    exit 0
else
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  SOME TESTS FAILED - Review logs before submission    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Check logs in /tmp/ for details"
    echo ""
    exit 1
fi
