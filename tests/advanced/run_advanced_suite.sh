#!/bin/bash
# Advanced Test Suite - Master Runner
# Created: 2026-01-21
# Purpose: Run all advanced tests comprehensively

set -e  # Exit on error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║      ADVANCED TEST SUITE - Assignment 3 SPL                 ║"
echo "║      Multi-Client | Channels | SQL | Reactor | Security     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test suite
run_suite() {
    local suite_name=$1
    local suite_script=$2
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Running: $suite_name${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ -f "$suite_script" ]; then
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        if bash "$suite_script"; then
            echo -e "${GREEN}✅ $suite_name PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}❌ $suite_name FAILED${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${YELLOW}⚠️  $suite_script not found, skipping${NC}"
    fi
    echo ""
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📁 Test Directory: $SCRIPT_DIR"
echo "⏰ Start Time: $(date)"
echo ""

# Run test suites in order
echo "🚀 Starting Advanced Test Suite Execution..."
echo ""

# Suite A: Multi-Client
run_suite "Suite A: Multi-Client Stress Test" "suite_a_multi_client/test_stress_10_clients.sh"
run_suite "Suite A: Client Lifecycle Test" "suite_a_multi_client/test_client_lifecycle.sh"

# Suite B: STOMP Commands
run_suite "Suite B: Subscribe/Unsubscribe" "suite_b_stomp_commands/test_subscribe_unsubscribe.sh"
run_suite "Suite B: Error Frames" "suite_b_stomp_commands/test_error_frames.sh"
run_suite "Suite B: Receipt Validation" "suite_b_stomp_commands/test_receipts.sh"

# Suite C: Channels
run_suite "Suite C: Channel Isolation" "suite_c_channels/test_channel_isolation.sh"
run_suite "Suite C: Channel Broadcast" "suite_c_channels/test_channel_broadcast.sh"

# Suite D: SQL
run_suite "Suite D: SQL Concurrency" "suite_d_sql/test_sql_concurrency.sh"
run_suite "Suite D: SQL Persistence" "suite_d_sql/test_sql_persistence.sh"
run_suite "Suite D: Large Data Test" "suite_d_sql/test_sql_large_data.sh"

# Suite E: Reactor
run_suite "Suite E: Reactor Server" "suite_e_reactor/test_reactor_server.sh"
run_suite "Suite E: Reactor vs TPC" "suite_e_reactor/test_reactor_vs_tpc.sh"

# Suite F: Security
run_suite "Suite F: Malformed Input" "suite_f_security/test_malformed_input.sh"
run_suite "Suite F: Resource Exhaustion" "suite_f_security/test_resource_exhaustion.sh"
run_suite "Suite F: Race Conditions" "suite_f_security/test_race_conditions.sh"

# Suite G: Scenarios
run_suite "Suite G: Full Game Scenario" "suite_g_scenarios/test_full_game_scenario.sh"
run_suite "Suite G: Multi-Match" "suite_g_scenarios/test_multi_match.sh"

# Final report
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   FINAL TEST RESULTS                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "⏰ End Time: $(date)"
echo "📊 Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}✅ Passed: $PASSED_TESTS${NC}"
echo -e "${RED}❌ Failed: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 ALL ADVANCED TESTS PASSED! 🎉                   ║${NC}"
    echo -e "${GREEN}║     Your assignment is ready for instructor review!         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║    ⚠️  SOME TESTS FAILED - Review Required  ⚠️              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
