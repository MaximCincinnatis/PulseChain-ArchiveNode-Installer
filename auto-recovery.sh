#!/bin/bash

# PulseChain Archive Node - Auto Recovery
# This script checks for common issues and automatically fixes them
# Designed to be run as a cron job, e.g.: 
# */10 * * * * /path/to/auto-recovery.sh >> /path/to/recovery.log 2>&1
# Adjust cron schedule based on your system load and monitoring needs

# ===================== CONFIGURABLE VARIABLES =====================
# Container names
GO_PULSE_CONTAINER="go-pulse"
LIGHTHOUSE_CONTAINER="lighthouse"

# Color definitions (disabled in non-interactive mode)
if [ -t 1 ]; then
    # Terminal is interactive, use colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    # Running from cron or non-interactive, no colors
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Helper function to colorize output
# Usage: colorize "message" COLOR
colorize() {
    local message="$1"
    local color="$2"
    
    # Only apply color if we have a color code
    if [ -n "$color" ]; then
        echo -e "${color}${message}${NC}"
    else
        echo "$message"
    fi
}

# Network settings
RPC_PORT=8545
RPC_URL="http://localhost:${RPC_PORT}"

# Thresholds
SYNC_THRESHOLD=1800  # 30 minutes in seconds - time before considering sync stuck
PEER_THRESHOLD=3     # Minimum acceptable number of peers
DISK_WARNING=90      # Disk usage percentage for warning
DISK_CRITICAL=95     # Disk usage percentage for critical warning

# Blockchain paths to check (in order of preference)
BLOCKCHAIN_PATHS=("/blockchain" "/var/lib/blockchain" "$HOME/blockchain")

# Wait times
WAIT_AFTER_STOP=10   # Seconds to wait after stopping containers
WAIT_AFTER_START=10  # Seconds to wait after starting go-pulse before starting lighthouse

# Exit codes
EXIT_SUCCESS=0
EXIT_DOCKER_NOT_INSTALLED=1
EXIT_DOCKER_SERVICE_FAILED=2
EXIT_DISK_CRITICAL=3           # Critical disk space issues
EXIT_CONTAINER_MISSING=4       # Container doesn't exist
EXIT_CONTAINER_START_FAILED=5  # Failed to start container
EXIT_RPC_ERROR=6               # RPC endpoint error
EXIT_SYNC_STUCK=7              # Sync is stuck
EXIT_LOW_PEERS=8               # Very low peer count
# ================================================================

# No color codes since this is meant for cron job output
echo "=========================================="
echo "PulseChain Archive Node - Auto Recovery"
date
echo "=========================================="

# Function to log messages
log() {
    local message="$1"
    local log_level="${2:-INFO}"
    
    local timestamp
    timestamp="[$(date +%H:%M:%S)]"
    
    case "$log_level" in
        ERROR)
            colorize "$timestamp ERROR: $message" "$RED"
            ;;
        WARNING)
            colorize "$timestamp WARNING: $message" "$YELLOW"
            ;;
        SUCCESS)
            colorize "$timestamp SUCCESS: $message" "$GREEN"
            ;;
        *)
            colorize "$timestamp $message" ""
            ;;
    esac
}

# Check if Docker is running
if ! command -v docker &> /dev/null; then
    log "Error: Docker is not installed." "ERROR"
    exit $EXIT_DOCKER_NOT_INSTALLED
fi

# Check if service is running
if ! systemctl is-active --quiet docker; then
    log "Docker service is not running. Attempting to start..." "WARNING"
    sudo systemctl start docker
    sleep 5
    
    if systemctl is-active --quiet docker; then
        log "Successfully started Docker service." "SUCCESS"
    else
        log "Failed to start Docker service. Manual intervention required." "ERROR"
        exit $EXIT_DOCKER_SERVICE_FAILED
    fi
fi

# Check container status - store results to avoid duplicate checks
log "Checking container status..." "INFO"
GO_PULSE_RUNNING=$(docker ps -q -f name=$GO_PULSE_CONTAINER)
LIGHTHOUSE_RUNNING=$(docker ps -q -f name=$LIGHTHOUSE_CONTAINER)
CONTAINERS_RUNNING=true

if [ -z "$GO_PULSE_RUNNING" ]; then
    CONTAINERS_RUNNING=false
    log "$GO_PULSE_CONTAINER container is not running" "WARNING"
else
    log "$GO_PULSE_CONTAINER container is running" "SUCCESS"
fi

if [ -z "$LIGHTHOUSE_RUNNING" ]; then
    CONTAINERS_RUNNING=false
    log "$LIGHTHOUSE_CONTAINER container is not running" "WARNING"
else
    log "$LIGHTHOUSE_CONTAINER container is running" "SUCCESS"
fi

# If containers aren't running, try to start them
if [ "$CONTAINERS_RUNNING" = false ]; then
    log "One or more containers are not running. Attempting to start..." "WARNING"
    
    # Check if containers exist but are stopped
    if docker ps -a -q -f name=$GO_PULSE_CONTAINER &> /dev/null; then
        log "Starting $GO_PULSE_CONTAINER container..." "INFO"
        docker start $GO_PULSE_CONTAINER
    else
        log "$GO_PULSE_CONTAINER container does not exist. Cannot auto-recover." "ERROR"
        exit $EXIT_CONTAINER_MISSING
    fi
    
    # Wait for go-pulse to initialize
    log "Waiting $WAIT_AFTER_START seconds for $GO_PULSE_CONTAINER to initialize..." "INFO"
    sleep $WAIT_AFTER_START
    
    if docker ps -a -q -f name=$LIGHTHOUSE_CONTAINER &> /dev/null; then
        log "Starting $LIGHTHOUSE_CONTAINER container..." "INFO"
        docker start $LIGHTHOUSE_CONTAINER
    else
        log "$LIGHTHOUSE_CONTAINER container does not exist. Cannot auto-recover." "ERROR"
        exit $EXIT_CONTAINER_MISSING
    fi
    
    log "Container start commands issued." "SUCCESS"
fi

# Function to make JSON-RPC calls with proper error handling
make_rpc_call() {
    local command=$1
    local result
    
    result=$(curl -s -m 5 -X POST -H "Content-Type: application/json" --data "$command" $RPC_URL || echo "curl_failed")
    
    if [[ $result == "curl_failed" ]]; then
        log "Error: RPC endpoint unavailable at $RPC_URL" "ERROR"
        return 1
    elif [[ $result == *"error"* && $result != *"result"* ]]; then
        # Simple error detection without complex parsing
        log "RPC error received from node" "ERROR"
        return 1
    fi
    
    echo "$result"
    return 0
}

# Function to parse hex values to decimal
hex_to_dec() {
    local hex=$1
    # Remove 0x prefix if present
    if [[ $hex == 0x* ]]; then
        hex="${hex:2}"
    fi
    echo $((16#$hex))
}

# Check for stuck sync - but only if go-pulse container is running
if [ -n "$GO_PULSE_RUNNING" ]; then
    log "Checking if sync is stuck..." "INFO"
    
    # Get current block timestamp
    TIMESTAMP_COMMAND='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}'
    if TIMESTAMP_RESULT=$(make_rpc_call "$TIMESTAMP_COMMAND") && [[ $TIMESTAMP_RESULT == *"timestamp"* ]]; then
        TIMESTAMP_HEX=$(echo "$TIMESTAMP_RESULT" | grep -o '"timestamp":"[^"]*' | cut -d'"' -f4)
        TIMESTAMP=$(hex_to_dec "$TIMESTAMP_HEX")
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - TIMESTAMP))
        
        # If latest block is over threshold old, restart containers
        if [ $TIME_DIFF -gt $SYNC_THRESHOLD ]; then
            log "Sync appears to be stuck. Latest block is $TIME_DIFF seconds old (threshold: $SYNC_THRESHOLD)." "ERROR"
            log "Restarting containers to recover..." "WARNING"
            
            # Graceful stop with timeout
            docker stop --time=60 $LIGHTHOUSE_CONTAINER
            docker stop --time=120 $GO_PULSE_CONTAINER
            
            # Wait for containers to fully stop
            log "Waiting $WAIT_AFTER_STOP seconds for containers to fully stop..." "INFO"
            sleep $WAIT_AFTER_STOP
            
            # Start in the correct order
            docker start $GO_PULSE_CONTAINER
            log "Waiting $WAIT_AFTER_START seconds for $GO_PULSE_CONTAINER to initialize..." "INFO"
            sleep $WAIT_AFTER_START
            docker start $LIGHTHOUSE_CONTAINER
            
            # Verify containers started successfully
            GO_PULSE_RESTARTED=$(docker ps -q -f name=$GO_PULSE_CONTAINER)
            LIGHTHOUSE_RESTARTED=$(docker ps -q -f name=$LIGHTHOUSE_CONTAINER)
            if [ -z "$GO_PULSE_RESTARTED" ] || [ -z "$LIGHTHOUSE_RESTARTED" ]; then
                log "WARNING: One or more containers failed to restart after sync recovery. Manual intervention may be required." "ERROR"
                exit $EXIT_CONTAINER_START_FAILED
            else
                log "Containers restarted successfully after sync recovery." "SUCCESS"
            fi
            
            log "Containers restarted in an attempt to recover sync." "SUCCESS"
            exit $EXIT_SYNC_STUCK
        else
            log "Sync appears to be working properly. Latest block is $TIME_DIFF seconds old (threshold: $SYNC_THRESHOLD)." "SUCCESS"
        fi
    else
        log "Could not determine latest block timestamp. Skipping sync check." "WARNING"
        exit $EXIT_RPC_ERROR
    fi
fi

# Check for low peer count - only if go-pulse container is running
if [ -n "$GO_PULSE_RUNNING" ]; then
    log "Checking peer count..." "INFO"
    
    PEER_COMMAND='{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
    if PEER_RESULT=$(make_rpc_call "$PEER_COMMAND") && [[ $PEER_RESULT == *"result"* ]]; then
        PEER_COUNT_HEX=$(echo "$PEER_RESULT" | grep -o '"result":"[^"]*' | cut -d'"' -f4)
        PEER_COUNT=$(hex_to_dec "$PEER_COUNT_HEX")
        
        if [ "$PEER_COUNT" -lt $PEER_THRESHOLD ]; then
            log "Very low peer count detected: $PEER_COUNT peers (threshold: $PEER_THRESHOLD)." "WARNING"
            log "Attempting network recovery by restarting $GO_PULSE_CONTAINER..." "WARNING"
            
            docker restart $GO_PULSE_CONTAINER
            
            # Verify container restarted successfully
            sleep 5  # Brief wait to let container initialize
            GO_PULSE_RESTARTED=$(docker ps -q -f name=$GO_PULSE_CONTAINER)
            if [ -z "$GO_PULSE_RESTARTED" ]; then
                log "WARNING: $GO_PULSE_CONTAINER failed to restart after peer recovery. Manual intervention may be required." "ERROR"
                exit $EXIT_CONTAINER_START_FAILED
            else
                log "$GO_PULSE_CONTAINER container restarted successfully for peer discovery." "SUCCESS"
            fi
            
            log "$GO_PULSE_CONTAINER container restarted to attempt peer discovery." "SUCCESS"
            exit $EXIT_LOW_PEERS
        else
            log "Peer count is acceptable: $PEER_COUNT peers (threshold: $PEER_THRESHOLD)." "SUCCESS"
        fi
    else
        log "Could not determine peer count. Skipping peer check." "WARNING"
        exit $EXIT_RPC_ERROR
    fi
fi

# Check disk space
log "Checking disk space..." "INFO"
BLOCKCHAIN_PATH=""

# Try to find blockchain directory from a running container
if [ -n "$GO_PULSE_RUNNING" ]; then
    # Check for both common mount points in go-pulse
    BLOCKCHAIN_PATH=$(docker inspect --format='{{ range .Mounts }}{{ if or (eq .Destination "/blockchain") (eq .Destination "/data") }}{{ .Source }}{{ end }}{{ end }}' $GO_PULSE_CONTAINER)
fi

# If lighthouse is running but go-pulse isn't, try that container
if [ -z "$BLOCKCHAIN_PATH" ] && [ -n "$LIGHTHOUSE_RUNNING" ]; then
    BLOCKCHAIN_PATH=$(docker inspect --format='{{ range .Mounts }}{{ if or (eq .Destination "/blockchain") (eq .Destination "/data") }}{{ .Source }}{{ end }}{{ end }}' $LIGHTHOUSE_CONTAINER)
fi

# If not found from running container, try from configured paths
if [ -z "$BLOCKCHAIN_PATH" ]; then
    # Check common locations from our configuration
    for dir in "${BLOCKCHAIN_PATHS[@]}"; do
        if [ -d "$dir" ]; then
            BLOCKCHAIN_PATH="$dir"
            log "Found blockchain directory at $BLOCKCHAIN_PATH" "SUCCESS"
            break
        fi
    done
fi

if [ -n "$BLOCKCHAIN_PATH" ]; then
    DF_OUTPUT=$(df -m "$BLOCKCHAIN_PATH")
    AVAILABLE_SPACE=$(echo "$DF_OUTPUT" | awk 'NR==2 {print $4}')
    TOTAL_SPACE=$(echo "$DF_OUTPUT" | awk 'NR==2 {print $2}')
    
    if [ -n "$AVAILABLE_SPACE" ] && [ -n "$TOTAL_SPACE" ] && [ "$TOTAL_SPACE" -gt 0 ]; then
        # Use pure Bash arithmetic instead of bc
        PERCENT_USED=$((100 - (AVAILABLE_SPACE * 100 / TOTAL_SPACE)))
        
        if [ "$PERCENT_USED" -gt $DISK_CRITICAL ]; then
            log "CRITICAL: Disk space critically low. $PERCENT_USED% used (threshold: $DISK_CRITICAL%)." "ERROR"
            log "Auto-recovery cannot resolve disk space issues. Manual intervention required." "ERROR"
            exit $EXIT_DISK_CRITICAL
        elif [ "$PERCENT_USED" -gt $DISK_WARNING ]; then
            log "WARNING: Disk space low. $PERCENT_USED% used (threshold: $DISK_WARNING%)." "WARNING"
        else
            log "Disk space is adequate. $PERCENT_USED% used." "SUCCESS"
        fi
    else
        log "Error parsing disk space information." "ERROR"
    fi
else
    log "Could not determine blockchain directory. Skipping disk space check." "WARNING"
    log "Looked for directories: ${BLOCKCHAIN_PATHS[*]}" "INFO"
fi

# Final status
log "Auto-recovery check completed." "SUCCESS"
echo "=========================================="
exit $EXIT_SUCCESS 