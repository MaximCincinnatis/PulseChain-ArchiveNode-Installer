#!/bin/bash

# PulseChain Archive Node - Simple Monitor
# This script provides basic status information about your PulseChain node
# Prerequisites: Docker running, go-pulse on port 8545, lighthouse on port 5052

# Configuration - customize these variables if needed
EXECUTION_PORT=8545
CONSENSUS_PORT=5052

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    PulseChain Archive Node - Status Monitor      ${NC}"
echo -e "${BLUE}=================================================${NC}"

# Check for required dependencies
for cmd in docker curl bc awk grep cut; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed${NC}"
        exit 1
    fi
done

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo -e "${RED}Error: Docker is not running or you don't have sufficient permissions.${NC}"
    echo -e "${YELLOW}Try starting Docker with: sudo systemctl start docker${NC}"
    exit 1
fi

# Function to get human-readable time from seconds
format_time() {
    local seconds=$1
    local days=$((seconds/86400))
    local hours=$(( (seconds%86400)/3600 ))
    local minutes=$(( (seconds%3600)/60 ))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${minutes}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Function to format disk space to be human-readable with 2 decimal places
format_disk_space() {
    local size=$1
    if (( $(echo "$size > 1000" | bc -l) )); then
        printf "%.2f TB" "$(echo "$size/1000" | bc -l)"
    else
        printf "%.2f GB" "$size"
    fi
}

# Check container status
echo -e "\n${BLUE}Container Status:${NC}"
if docker ps -q -f name=go-pulse &>/dev/null; then
    echo -e "${GREEN}✓ Execution Client (go-pulse): Running${NC}"
    
    # Get uptime
    CREATED=$(docker inspect --format='{{.Created}}' go-pulse 2>/dev/null)
    if [ -n "$CREATED" ]; then
        # More portable timestamp parsing
        CREATED_SECONDS=$(date --date="$CREATED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED" +%s 2>/dev/null)
        
        if [ -n "$CREATED_SECONDS" ]; then
            CURRENT_SECONDS=$(date +%s)
            UPTIME_SECONDS=$((CURRENT_SECONDS - CREATED_SECONDS))
            UPTIME=$(format_time $UPTIME_SECONDS)
            echo -e "   Uptime: $UPTIME"
        else
            echo -e "   ${YELLOW}! Unable to calculate uptime - date command incompatibility${NC}"
        fi
    else
        echo -e "   ${YELLOW}! Unable to inspect container${NC}"
    fi
else
    echo -e "${RED}✗ Execution Client (go-pulse): Not running${NC}"
    echo -e "   ${YELLOW}Run ./restart.sh to start the node${NC}"
fi

if docker ps -q -f name=lighthouse &>/dev/null; then
    echo -e "${GREEN}✓ Consensus Client (lighthouse): Running${NC}"
    
    # Get uptime
    CREATED=$(docker inspect --format='{{.Created}}' lighthouse 2>/dev/null)
    if [ -n "$CREATED" ]; then
        # More portable timestamp parsing
        CREATED_SECONDS=$(date -d "$CREATED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED" +%s 2>/dev/null)
        NOW_SECONDS=$(date +%s)
        UPTIME_SECONDS=$((NOW_SECONDS - CREATED_SECONDS))
        echo -e "   Uptime: $(format_time $UPTIME_SECONDS)"
    fi
else
    echo -e "${RED}✗ Consensus Client (lighthouse): Not running${NC}"
    echo -e "   ${YELLOW}Run ./restart.sh to start the node${NC}"
fi

# Check sync status (execution client)
echo -e "\n${BLUE}Sync Status:${NC}"
if docker ps -q -f name=go-pulse &>/dev/null; then
    SYNC_COMMAND='{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
    SYNC_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$SYNC_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
    
    if [[ $SYNC_RESULT == "error" ]]; then
        echo -e "   ${RED}Failed to connect to execution client RPC on port $EXECUTION_PORT${NC}"
    else
        # Also get the latest block
        BLOCK_COMMAND='{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
        BLOCK_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$BLOCK_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
        
        if [[ $BLOCK_RESULT == "error" ]]; then
            echo -e "   ${RED}Failed to get block number from execution client${NC}"
        elif [[ $BLOCK_RESULT == *"result"* ]]; then
            CURRENT_BLOCK_HEX=$(echo "$BLOCK_RESULT" | grep -o '"result":"[^"]*' | cut -d'"' -f4)
            CURRENT_BLOCK=$((16#${CURRENT_BLOCK_HEX:2}))
            echo -e "   Current block: $CURRENT_BLOCK"
            
            # Get timestamp of latest block
            TIMESTAMP_COMMAND='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}'
            TIMESTAMP_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$TIMESTAMP_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
            
            if [[ $TIMESTAMP_RESULT == "error" ]]; then
                echo -e "   ${RED}Failed to get block timestamp from execution client${NC}"
            elif [[ $TIMESTAMP_RESULT == *"timestamp"* ]]; then
                TIMESTAMP_HEX=$(echo "$TIMESTAMP_RESULT" | grep -o '"timestamp":"[^"]*' | cut -d'"' -f4)
                TIMESTAMP=$((16#${TIMESTAMP_HEX:2}))
                CURRENT_TIME=$(date +%s)
                TIME_DIFF=$((CURRENT_TIME - TIMESTAMP))
                
                if [ $TIME_DIFF -lt 60 ]; then
                    echo -e "   ${GREEN}Block age: $TIME_DIFF seconds${NC}"
                elif [ $TIME_DIFF -lt 300 ]; then
                    echo -e "   ${YELLOW}Block age: $(format_time $TIME_DIFF)${NC}"
                else
                    echo -e "   ${RED}Block age: $(format_time $TIME_DIFF)${NC}"
                fi
            fi
        fi
        
        if [[ $SYNC_RESULT == *"false"* ]]; then
            echo -e "   ${GREEN}Execution client: SYNCED${NC}"
        elif [[ $SYNC_RESULT == *"currentBlock"* ]]; then
            CURRENT_BLOCK=$(echo "$SYNC_RESULT" | grep -o '"currentBlock":"[^"]*' | cut -d '"' -f 4)
            HIGHEST_BLOCK=$(echo "$SYNC_RESULT" | grep -o '"highestBlock":"[^"]*' | cut -d '"' -f 4)
            
            # Convert from hex to decimal
            CURRENT_BLOCK_DEC=$((16#${CURRENT_BLOCK:2}))
            HIGHEST_BLOCK_DEC=$((16#${HIGHEST_BLOCK:2}))
            
            echo -e "   ${YELLOW}Execution client: SYNCING${NC}"
            echo "   Current block: $CURRENT_BLOCK_DEC"
            echo "   Target block: $HIGHEST_BLOCK_DEC"
            
            # Calculate percentage
            if [ $HIGHEST_BLOCK_DEC -gt 0 ]; then
                PERCENTAGE=$(echo "scale=2; $CURRENT_BLOCK_DEC * 100 / $HIGHEST_BLOCK_DEC" | bc | sed 's/\.00$//')
                echo "   Progress: $PERCENTAGE%"
            fi
        else
            echo -e "   ${RED}Execution client: UNKNOWN STATE${NC}"
            echo "   Unable to determine sync status"
        fi
    fi
else
    echo -e "   ${RED}Execution client not running${NC}"
    echo -e "   ${YELLOW}Run ./restart.sh to start the node${NC}"
fi

# Check beacon node sync
if docker ps -q -f name=lighthouse &>/dev/null; then
    LIGHTHOUSE_STATUS=$(curl -s --connect-timeout 5 http://localhost:$CONSENSUS_PORT/eth/v1/node/syncing || echo "error")
    
    if [[ $LIGHTHOUSE_STATUS == "error" ]]; then
        echo -e "   ${RED}Failed to connect to consensus client API on port $CONSENSUS_PORT${NC}"
    elif [[ $LIGHTHOUSE_STATUS == *"is_syncing\":false"* ]]; then
        echo -e "   ${GREEN}Consensus client: SYNCED${NC}"
    elif [[ $LIGHTHOUSE_STATUS == *"head_slot"* ]]; then
        HEAD_SLOT=$(echo "$LIGHTHOUSE_STATUS" | grep -o '"head_slot":"[^"]*' | cut -d '"' -f 4)
        SYNC_DISTANCE=$(echo "$LIGHTHOUSE_STATUS" | grep -o '"sync_distance":"[^"]*' | cut -d '"' -f 4)
        
        echo -e "   ${YELLOW}Consensus client: SYNCING${NC}"
        echo "   Current slot: $HEAD_SLOT"
        echo "   Slots behind: $SYNC_DISTANCE"
    else
        echo -e "   ${RED}Consensus client: UNKNOWN STATE${NC}"
    fi
else
    echo -e "   ${RED}Consensus client not running${NC}"
    echo -e "   ${YELLOW}Run ./restart.sh to start the node${NC}"
fi

# Check peer count
echo -e "\n${BLUE}Network Status:${NC}"
if docker ps -q -f name=go-pulse &>/dev/null; then
    PEER_COMMAND='{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
    PEER_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$PEER_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
    
    if [[ $PEER_RESULT == "error" ]]; then
        echo -e "   ${RED}Failed to get peer count from execution client${NC}"
    elif [[ $PEER_RESULT == *"result"* ]]; then
        PEER_COUNT_HEX=$(echo "$PEER_RESULT" | grep -o '"result":"[^"]*' | cut -d'"' -f4)
        PEER_COUNT=$((16#${PEER_COUNT_HEX:2}))
        
        if [ "$PEER_COUNT" -lt 5 ]; then
            echo -e "   ${RED}Execution peers: $PEER_COUNT${NC} (very low)"
        elif [ "$PEER_COUNT" -lt 15 ]; then
            echo -e "   ${YELLOW}Execution peers: $PEER_COUNT${NC} (low)"
        else
            echo -e "   ${GREEN}Execution peers: $PEER_COUNT${NC}"
        fi
    else
        echo -e "   ${RED}Failed to get execution peer count${NC}"
    fi
fi

if docker ps -q -f name=lighthouse &>/dev/null; then
    LIGHTHOUSE_PEERS=$(curl -s --connect-timeout 5 http://localhost:$CONSENSUS_PORT/eth/v1/node/peer_count || echo "error")
    
    if [[ $LIGHTHOUSE_PEERS == "error" ]]; then
        echo -e "   ${RED}Failed to get peer count from consensus client${NC}"
    elif [[ $LIGHTHOUSE_PEERS == *"connected"* ]]; then
        PEER_COUNT=$(echo "$LIGHTHOUSE_PEERS" | grep -o '"connected":[^,]*' | cut -d ':' -f 2)
        
        if [ "$PEER_COUNT" -lt 5 ]; then
            echo -e "   ${RED}Consensus peers: $PEER_COUNT${NC} (very low)"
        elif [ "$PEER_COUNT" -lt 15 ]; then
            echo -e "   ${YELLOW}Consensus peers: $PEER_COUNT${NC} (low)"
        else
            echo -e "   ${GREEN}Consensus peers: $PEER_COUNT${NC}"
        fi
    else
        echo -e "   ${RED}Failed to get consensus peer count${NC}"
    fi
fi

# Check disk space
echo -e "\n${BLUE}System Resources:${NC}"
# Find blockchain directory from a running container
BLOCKCHAIN_PATH=""

if docker ps -q -f name=go-pulse &>/dev/null; then
    # Check for both common mount points in go-pulse
    BLOCKCHAIN_PATH=$(docker inspect --format='{{ range .Mounts }}{{ if or (eq .Destination "/blockchain") (eq .Destination "/data") }}{{ .Source }}{{ end }}{{ end }}' go-pulse 2>/dev/null)
fi

# If go-pulse didn't give us a path, try lighthouse
if [ -z "$BLOCKCHAIN_PATH" ] && docker ps -q -f name=lighthouse &>/dev/null; then
    BLOCKCHAIN_PATH=$(docker inspect --format='{{ range .Mounts }}{{ if or (eq .Destination "/blockchain") (eq .Destination "/data") }}{{ .Source }}{{ end }}{{ end }}' lighthouse 2>/dev/null)
fi

# If still not found, try common locations
if [ -z "$BLOCKCHAIN_PATH" ]; then
    for dir in "/blockchain" "/var/lib/blockchain" "$HOME/blockchain"; do
        if [ -d "$dir" ]; then
            BLOCKCHAIN_PATH="$dir"
            break
        fi
    done
fi
    
if [ -n "$BLOCKCHAIN_PATH" ]; then
    if [ -d "$BLOCKCHAIN_PATH" ]; then
        BLOCKCHAIN_SPACE_USED=$(du -sm "$BLOCKCHAIN_PATH" 2>/dev/null | awk '{print $1}')
        BLOCKCHAIN_SPACE_AVAILABLE=$(df -m "$BLOCKCHAIN_PATH" 2>/dev/null | awk 'NR==2 {print $4}')
        BLOCKCHAIN_SPACE_TOTAL=$(df -m "$BLOCKCHAIN_PATH" 2>/dev/null | awk 'NR==2 {print $2}')
        
        if [ -n "$BLOCKCHAIN_SPACE_USED" ] && [ -n "$BLOCKCHAIN_SPACE_AVAILABLE" ] && [ -n "$BLOCKCHAIN_SPACE_TOTAL" ]; then
            # Convert to GB for readability
            USED_GB=$(echo "scale=2; $BLOCKCHAIN_SPACE_USED/1024" | bc)
            AVAILABLE_GB=$(echo "scale=2; $BLOCKCHAIN_SPACE_AVAILABLE/1024" | bc)
            TOTAL_GB=$(echo "scale=2; $BLOCKCHAIN_SPACE_TOTAL/1024" | bc)
            PERCENT_USED=$(echo "scale=0; 100-($BLOCKCHAIN_SPACE_AVAILABLE*100/$BLOCKCHAIN_SPACE_TOTAL)" | bc)
            
            echo -e "   Blockchain data size: $(format_disk_space "$USED_GB")"
            
            if [ "$PERCENT_USED" -gt 90 ]; then
                echo -e "   Disk space: ${RED}$PERCENT_USED% used${NC} ($(format_disk_space "$AVAILABLE_GB") free of $(format_disk_space "$TOTAL_GB"))"
            elif [ "$PERCENT_USED" -gt 80 ]; then
                echo -e "   Disk space: ${YELLOW}$PERCENT_USED% used${NC} ($(format_disk_space "$AVAILABLE_GB") free of $(format_disk_space "$TOTAL_GB"))"
            else
                echo -e "   Disk space: ${GREEN}$PERCENT_USED% used${NC} ($(format_disk_space "$AVAILABLE_GB") free of $(format_disk_space "$TOTAL_GB"))"
            fi
        else
            echo -e "   ${RED}Unable to determine disk space usage${NC}"
        fi
    else
        echo -e "   ${RED}Blockchain directory not found: $BLOCKCHAIN_PATH${NC}"
    fi
else
    echo -e "   ${YELLOW}Unable to determine blockchain data path from container mounts${NC}"
fi

# Check RAM usage
MEM_TOTAL=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
if [ -z "$MEM_TOTAL" ]; then
    # Try alternative for macOS
    MEM_TOTAL=$(top -l 1 2>/dev/null | grep PhysMem | awk '{print $2}' | sed 's/[^0-9]//g')
    MEM_USED=$(top -l 1 2>/dev/null | grep PhysMem | awk '{print $6}' | sed 's/[^0-9]//g')
fi

if [ -n "$MEM_TOTAL" ] && [ -n "$MEM_USED" ]; then
    MEM_PERCENT=$(echo "scale=0; $MEM_USED*100/$MEM_TOTAL" | bc)
    
    if [ "$MEM_PERCENT" -gt 90 ]; then
        echo -e "   RAM usage: ${RED}$MEM_PERCENT%${NC} ($MEM_USED MB of $MEM_TOTAL MB)"
    elif [ "$MEM_PERCENT" -gt 80 ]; then
        echo -e "   RAM usage: ${YELLOW}$MEM_PERCENT%${NC} ($MEM_USED MB of $MEM_TOTAL MB)"
    else
        echo -e "   RAM usage: ${GREEN}$MEM_PERCENT%${NC} ($MEM_USED MB of $MEM_TOTAL MB)"
    fi
else
    echo -e "   ${YELLOW}Unable to determine RAM usage${NC}"
fi

# Check CPU usage for Docker containers
echo -e "   Container resource usage:"
CONTAINER_STATS=$(docker stats --no-stream --format "   {{.Name}}: {{.CPUPerc}} CPU, {{.MemUsage}}" go-pulse lighthouse 2>/dev/null)
if [ -n "$CONTAINER_STATS" ]; then 
    echo "$CONTAINER_STATS"
else
    echo "   No running containers found or unable to get statistics"
fi

# Check for recent errors in container logs (last 50 lines only to avoid performance impact)
echo -e "\n${BLUE}Recent Log Errors (last 50 lines):${NC}"
if docker ps -q -f name=go-pulse &>/dev/null; then
    ERROR_COUNT=$(docker logs --tail 50 go-pulse 2>&1 | grep -c -i "error\|exception\|fatal")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "   ${YELLOW}! $ERROR_COUNT recent error(s) found in go-pulse logs${NC}"
        echo -e "     Run 'docker logs go-pulse | grep -i error' to view"
    else
        echo -e "   ${GREEN}✓ No recent errors found in go-pulse logs${NC}"
    fi
else
    echo -e "   ${RED}✗ go-pulse container not running${NC}"
fi

if docker ps -q -f name=lighthouse &>/dev/null; then
    ERROR_COUNT=$(docker logs --tail 50 lighthouse 2>&1 | grep -c -i "error\|exception\|fatal")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "   ${YELLOW}! $ERROR_COUNT recent error(s) found in lighthouse logs${NC}"
        echo -e "     Run 'docker logs lighthouse | grep -i error' to view"
    else
        echo -e "   ${GREEN}✓ No recent errors found in lighthouse logs${NC}"
    fi
else
    echo -e "   ${RED}✗ lighthouse container not running${NC}"
fi

# Check for common issues
echo -e "\n${BLUE}Health Check:${NC}"
ISSUES_FOUND=0

# Check for stuck sync (no progress in blocks for over 30 minutes)
if docker ps -q -f name=go-pulse &>/dev/null; then
    # Get current block number
    BLOCK_COMMAND='{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
    BLOCK_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$BLOCK_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
    
    if [[ $BLOCK_RESULT == "error" ]]; then
        echo -e "   ${RED}✗ Unable to check sync status - connection to execution client failed${NC}"
        ISSUES_FOUND=1
    elif [[ $BLOCK_RESULT == *"result"* ]]; then
        CURRENT_BLOCK_HEX=$(echo "$BLOCK_RESULT" | grep -o '"result":"[^"]*' | cut -d'"' -f4)
        CURRENT_BLOCK=$((16#${CURRENT_BLOCK_HEX:2}))
        
        # Get timestamp of latest block
        TIMESTAMP_COMMAND='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}'
        TIMESTAMP_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$TIMESTAMP_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
        
        if [[ $TIMESTAMP_RESULT == "error" ]]; then
            echo -e "   ${RED}✗ Unable to check sync status - connection to execution client failed${NC}"
            ISSUES_FOUND=1
        elif [[ $TIMESTAMP_RESULT == *"timestamp"* ]]; then
            TIMESTAMP_HEX=$(echo "$TIMESTAMP_RESULT" | grep -o '"timestamp":"[^"]*' | cut -d'"' -f4)
            TIMESTAMP=$((16#${TIMESTAMP_HEX:2}))
            CURRENT_TIME=$(date +%s)
            TIME_DIFF=$((CURRENT_TIME - TIMESTAMP))
            
            # If latest block is over 30 minutes old
            if [ $TIME_DIFF -gt 1800 ]; then
                echo -e "   ${RED}✗ Sync may be stuck - latest block is $(format_time $TIME_DIFF) old${NC}"
                echo -e "     Recommendation: Try 'docker restart go-pulse lighthouse' to resume sync"
                ISSUES_FOUND=1
            fi
        fi
    fi
fi

# Check for low peer count
if docker ps -q -f name=go-pulse &>/dev/null; then
    PEER_COMMAND='{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
    PEER_RESULT=$(curl -s --connect-timeout 5 -X POST -H "Content-Type: application/json" --data "$PEER_COMMAND" http://localhost:$EXECUTION_PORT || echo "error")
    
    if [[ $PEER_RESULT == "error" ]]; then
        echo -e "   ${RED}✗ Unable to check peer count - connection to execution client failed${NC}"
        ISSUES_FOUND=1
    elif [[ $PEER_RESULT == *"result"* ]]; then
        PEER_COUNT_HEX=$(echo "$PEER_RESULT" | grep -o '"result":"[^"]*' | cut -d'"' -f4)
        PEER_COUNT=$((16#${PEER_COUNT_HEX:2}))
        
        if [ $PEER_COUNT -lt 5 ]; then
            echo -e "   ${RED}✗ Very low execution peer count ($PEER_COUNT)${NC}"
            echo -e "     Recommendation: Check firewall settings for port 30303"
            ISSUES_FOUND=1
        fi
    fi
fi

# Check for low disk space
if [ -n "$BLOCKCHAIN_SPACE_AVAILABLE" ] && [ -n "$BLOCKCHAIN_SPACE_TOTAL" ]; then
    PERCENT_USED=$(echo "scale=0; 100-($BLOCKCHAIN_SPACE_AVAILABLE*100/$BLOCKCHAIN_SPACE_TOTAL)" | bc)
    
    if [ "$PERCENT_USED" -gt 90 ]; then
        echo -e "   ${RED}✗ Critically low disk space ($PERCENT_USED% used)${NC}"
        echo -e "     Recommendation: Free up space or expand storage"
        ISSUES_FOUND=1
    elif [ "$PERCENT_USED" -gt 80 ]; then
        echo -e "   ${YELLOW}! Low disk space ($PERCENT_USED% used)${NC}"
        echo -e "     Recommendation: Monitor closely and plan for expansion"
        ISSUES_FOUND=1
    fi
fi

# Verify required scripts exist
for script in "./restart.sh" "./edit-parameters.sh"; do
    if [ ! -f "$script" ]; then
        echo -e "   ${YELLOW}! Referenced script $script does not exist${NC}"
        ISSUES_FOUND=1
    fi
done

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "   ${GREEN}✓ No issues detected${NC}"
fi

echo -e "\n${BLUE}Helpful Commands:${NC}"
echo "   View go-pulse logs: docker logs -f go-pulse"
echo "   View lighthouse logs: docker logs -f lighthouse"
if [ -f "./restart.sh" ]; then
    echo "   Restart node: ./restart.sh"
fi
if [ -f "./edit-parameters.sh" ]; then
    echo "   Edit parameters: ./edit-parameters.sh"
fi

echo -e "\n${GREEN}Monitor check completed!${NC}" 

# Exit with status code based on issues found
if [ $ISSUES_FOUND -gt 0 ]; then
    exit 1
else
    exit 0
fi 