#!/bin/bash

# Server Stress Test - Multiple concurrent clients

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       SERVER STRESS TEST - Concurrent Clients                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if server is running
echo -e "${BLUE}[TEST]${NC} Checking if server is running..."
if ! timeout 2 bash -c "echo > /dev/tcp/localhost/7777" 2>/dev/null; then
    echo -e "${RED}❌ Server is not running!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Server is running${NC}"
echo ""

CLIENT_BIN="../client/bin/StompWCIClient"
if [ ! -f "$CLIENT_BIN" ]; then
    echo -e "${RED}❌ Client binary not found${NC}"
    exit 1
fi

NUM_CLIENTS=10
echo -e "${BLUE}[TEST]${NC} Launching $NUM_CLIENTS concurrent clients..."
echo ""

# Function to run a single client
run_client() {
    local CLIENT_ID=$1
    local LOG_FILE="stress_client_${CLIENT_ID}.log"
    
    cat > stress_client_${CLIENT_ID}.input << EOF
login localhost:7777 stress_user_${CLIENT_ID} pass${CLIENT_ID}
join test_channel_${CLIENT_ID}
exit test_channel_${CLIENT_ID}
logout
EOF
    
    timeout 10s $CLIENT_BIN localhost 7777 < stress_client_${CLIENT_ID}.input > $LOG_FILE 2>&1
    
    if grep -q "Login successful" $LOG_FILE; then
        echo -e "${GREEN}✅ Client $CLIENT_ID: Success${NC}"
        return 0
    else
        echo -e "${RED}❌ Client $CLIENT_ID: Failed${NC}"
        return 1
    fi
}

# Launch clients in parallel
SUCCESS_COUNT=0
PIDS=()

for i in $(seq 1 $NUM_CLIENTS); do
    run_client $i &
    PIDS+=($!)
    sleep 0.1  # Small delay between launches
done

# Wait for all clients
echo ""
echo "Waiting for all clients to complete..."
for pid in "${PIDS[@]}"; do
    wait $pid
    if [ $? -eq 0 ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Results:${NC}"
echo -e "  Total clients: $NUM_CLIENTS"
echo -e "  Successful: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "  Failed: ${RED}$((NUM_CLIENTS - SUCCESS_COUNT))${NC}"

# Cleanup
rm -f stress_client_*.input stress_client_*.log

echo ""
if [ $SUCCESS_COUNT -eq $NUM_CLIENTS ]; then
    echo -e "${GREEN}✅ Server handled all $NUM_CLIENTS concurrent clients successfully!${NC}"
    echo -e "${GREEN}✅ Reactor/TPC implementation is working correctly${NC}"
else
    echo -e "${YELLOW}⚠️  Server handled $SUCCESS_COUNT/$NUM_CLIENTS clients${NC}"
fi
echo ""
