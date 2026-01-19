#!/bin/bash

# Quick Server Starter for Tests

echo "🚀 Starting STOMP Server on port 7777..."
echo ""
echo "Press Ctrl+C to stop the server"
echo "════════════════════════════════════════"
echo ""

cd "$(dirname "$0")/../server"

# Check if pom.xml exists
if [ ! -f "pom.xml" ]; then
    echo "❌ Error: pom.xml not found. Are you in the right directory?"
    exit 1
fi

# Start server
mvn exec:java -Dexec.mainClass="bgu.spl.net.impl.stomp.StompServer" -Dexec.args="7777"
