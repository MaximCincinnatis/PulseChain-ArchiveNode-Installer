#!/bin/bash

# PulseChain Archive Node Status Check
# This script checks the status of your PulseChain node

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration variables
RPC_PORT=8545
LIGHTHOUSE_PORT=5052

echo -e "${GREEN}PulseChain Archive Node - Status Check${NC}"

# Check for required dependencies
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed.${NC}"
    exit 1
fi

# Check if jq is installed (recommended but not required)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq is not installed. jq enables more reliable JSON parsing.${NC}"
    read -p "Would you like to install jq now? (Y/n): " -r INSTALL_JQ
    if [[ ! $INSTALL_JQ =~ ^[Nn]$ ]]; then
        echo "Installing jq..."
        if sudo apt update && sudo apt install -y jq; then
            echo -e "${GREEN}✓ jq installed successfully${NC}"
        else
            echo -e "${RED}Failed to install jq. Will use fallback parsing method.${NC}"
            echo -e "${YELLOW}You can manually install jq later with: sudo apt install -y jq${NC}"
        fi
    else
        echo -e "${YELLOW}Skipping jq installation. Will use fallback parsing method.${NC}"
    fi
    echo ""
fi

# Check if the user has Docker permissions
if ! docker ps &> /dev/null; then
    echo -e "${RED}Error: User lacks Docker permissions. Try running with sudo or add user to the docker group.${NC}"
    exit 1
fi

# Check if the containers are running
if [ "$(docker ps -q -f name=go-pulse)" ]; then
    echo -e "${GREEN}✓ go-pulse container is running${NC}"
    
    # Get container details
    CONTAINER_ID=$(docker ps -q -f name=go-pulse)
    UPTIME=$(docker ps --format "{{.RunningFor}}" -f name=go-pulse)
    IMAGE=$(docker ps --format "{{.Image}}" -f name=go-pulse)
    
    echo "   Container ID: $CONTAINER_ID"
    echo "   Running for: $UPTIME"
    echo "   Image: $IMAGE"
    
    # Get sync status
    echo -e "\n${YELLOW}Checking sync status...${NC}"
    SYNC_COMMAND='{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
    SYNC_RESULT=$(curl -s -m 5 -X POST -H "Content-Type: application/json" --data "$SYNC_COMMAND" http://localhost:$RPC_PORT)
    
    if [[ -z "$SYNC_RESULT" ]]; then
        echo -e "${RED}✗ Could not connect to the RPC endpoint (http://localhost:$RPC_PORT). Check if the node is running.${NC}"
    elif [[ $SYNC_RESULT == *"false"* ]]; then
        echo -e "${GREEN}✓ Node is fully synced${NC}"
    else
        echo -e "${YELLOW}⟳ Node is still syncing${NC}"
        # Extract more info if available
        if [[ $SYNC_RESULT == *"currentBlock"* ]]; then
            # Try using jq if available for more reliable JSON parsing
            if command -v jq &> /dev/null; then
                CURRENT_BLOCK=$(echo "$SYNC_RESULT" | jq -r '.result.currentBlock')
                HIGHEST_BLOCK=$(echo "$SYNC_RESULT" | jq -r '.result.highestBlock')
            else
                # Fall back to grep/cut if jq is not installed
                CURRENT_BLOCK=$(echo "$SYNC_RESULT" | grep -o '"currentBlock":"[^"]*' | cut -d '"' -f 4)
                HIGHEST_BLOCK=$(echo "$SYNC_RESULT" | grep -o '"highestBlock":"[^"]*' | cut -d '"' -f 4)
            fi
            
            # Convert from hex to decimal
            CURRENT_BLOCK_DEC=$((16#${CURRENT_BLOCK:2}))
            HIGHEST_BLOCK_DEC=$((16#${HIGHEST_BLOCK:2}))
            
            echo "   Current block: $CURRENT_BLOCK_DEC"
            echo "   Highest block: $HIGHEST_BLOCK_DEC"
            
            # Calculate percentage
            if [ $HIGHEST_BLOCK_DEC -gt 0 ]; then
                PERCENTAGE=$(echo "scale=2; $CURRENT_BLOCK_DEC * 100 / $HIGHEST_BLOCK_DEC" | bc)
                echo "   Sync progress: $PERCENTAGE%"
            fi
        fi
    fi
else
    echo -e "${RED}✗ go-pulse container is not running${NC}"
fi

# Check lighthouse container
if [ "$(docker ps -q -f name=lighthouse)" ]; then
    echo -e "\n${GREEN}✓ lighthouse container is running${NC}"
    
    # Get container details
    CONTAINER_ID=$(docker ps -q -f name=lighthouse)
    UPTIME=$(docker ps --format "{{.RunningFor}}" -f name=lighthouse)
    IMAGE=$(docker ps --format "{{.Image}}" -f name=lighthouse)
    
    echo "   Container ID: $CONTAINER_ID"
    echo "   Running for: $UPTIME"
    echo "   Image: $IMAGE"
    
    # Try to check lighthouse sync status
    echo -e "\n${YELLOW}Checking lighthouse status...${NC}"
    LIGHTHOUSE_STATUS=$(curl -s -m 5 http://localhost:$LIGHTHOUSE_PORT/eth/v1/node/syncing)
    
    if [[ -z "$LIGHTHOUSE_STATUS" ]]; then
        echo -e "${RED}✗ Could not connect to the Lighthouse endpoint (http://localhost:$LIGHTHOUSE_PORT). Check if the beacon node is running.${NC}"
    elif [[ $LIGHTHOUSE_STATUS == *"is_syncing\":false"* ]]; then
        echo -e "${GREEN}✓ Beacon node is fully synced${NC}"
    else
        echo -e "${YELLOW}⟳ Beacon node is still syncing${NC}"
        # Try to extract more info if available
        if [[ $LIGHTHOUSE_STATUS == *"head_slot"* ]]; then
            # Try using jq if available for more reliable JSON parsing
            if command -v jq &> /dev/null; then
                HEAD_SLOT=$(echo "$LIGHTHOUSE_STATUS" | jq -r '.data.head_slot')
                SYNC_DISTANCE=$(echo "$LIGHTHOUSE_STATUS" | jq -r '.data.sync_distance')
            else
                # Fall back to grep/cut if jq is not installed
                HEAD_SLOT=$(echo "$LIGHTHOUSE_STATUS" | grep -o '"head_slot":"[^"]*' | cut -d '"' -f 4)
                SYNC_DISTANCE=$(echo "$LIGHTHOUSE_STATUS" | grep -o '"sync_distance":"[^"]*' | cut -d '"' -f 4)
            fi
            
            echo "   Head slot: $HEAD_SLOT"
            echo "   Sync distance: $SYNC_DISTANCE slots behind"
        fi
    fi
else
    echo -e "\n${RED}✗ lighthouse container is not running${NC}"
fi

# Check system resources
echo -e "\n${GREEN}System Resource Usage:${NC}"
echo "CPU usage for containers:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" go-pulse lighthouse 2>/dev/null || echo "No running containers found"

# Show basic host resource information
echo -e "\n${GREEN}Host Resources:${NC}"
echo "RAM: $(free -h | awk '/^Mem:/ {print $3 " used of " $2 " total"}')"
echo "Disk: $(df -h | grep "$(docker info --format '{{.DockerRootDir}}' | cut -d'/' -f1)" | awk '{print $3 " used of " $2 " total (" $5 " used)"}')"

# Provide helpful commands
echo -e "\n${YELLOW}Helpful Commands:${NC}"
echo "View go-pulse logs: sudo docker logs -f go-pulse"
echo "View lighthouse logs: sudo docker logs -f lighthouse"
echo "Restart both containers: sudo docker restart go-pulse lighthouse"

echo -e "\n${GREEN}Status check completed!${NC}" 