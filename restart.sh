#!/bin/bash

# PulseChain Archive Node - Start/Restart
# This script starts the PulseChain Archive Node containers

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Trap interrupts for clean exit
trap 'echo -e "${RED}Script interrupted.${NC}"; exit 1' INT TERM

# Parse command line arguments
SHOW_LOGS=false
WAIT_TIME=10

while [[ $# -gt 0 ]]; do
    case $1 in
        --show-logs)
            SHOW_LOGS=true
            shift
            ;;
        [0-9]*)
            WAIT_TIME="$1"
            shift
            ;;
        *)
            # Unknown option
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [WAIT_TIME] [--show-logs]"
            echo "  WAIT_TIME: seconds to wait for go-pulse to initialize (default: 10)"
            echo "  --show-logs: automatically show logs if containers fail to start"
            exit 1
            ;;
    esac
done

# Print banner
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}    PulseChain Archive Node - Start/Restart       ${NC}"
echo -e "${GREEN}=================================================${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running. Start it with 'sudo systemctl start docker'.${NC}"
    exit 1
fi

# Function to check if container exists
container_exists() {
    local container_name=$1
    if [ "$(docker ps -a -q -f name="$container_name")" ]; then
        return 0 # True
    else
        return 1 # False
    fi
}

# Function to check if container is running
container_running() {
    local container_name=$1
    if [ "$(docker ps -q -f name="$container_name")" ]; then
        return 0 # True
    else
        return 1 # False
    fi
}

# Restart the containers in the correct order
echo -e "${YELLOW}Starting PulseChain node containers...${NC}"

# First, check for and start the go-pulse (execution layer) container
if container_exists go-pulse; then
    if container_running go-pulse; then
        echo -e "${YELLOW}Go-pulse container is already running.${NC}"
    else
        echo "Starting go-pulse container..."
        if docker start go-pulse; then
            echo -e "${GREEN}Go-pulse container started successfully.${NC}"
        else
            echo -e "${RED}Failed to start go-pulse container. Check logs with: docker logs go-pulse${NC}"
            if [ "$SHOW_LOGS" = true ]; then
                echo -e "${YELLOW}Showing go-pulse logs:${NC}"
                docker logs --tail 50 go-pulse
            fi
            exit 1
        fi
    fi
else
    echo -e "${RED}Go-pulse container not found. Run install.sh to set up the node.${NC}"
    exit 1
fi

# Wait a moment for go-pulse to initialize
echo "Waiting for go-pulse to initialize ($WAIT_TIME seconds)..."
sleep "$WAIT_TIME"

# Then, check for and start the lighthouse (beacon chain) container
if container_exists lighthouse; then
    if container_running lighthouse; then
        echo -e "${YELLOW}Lighthouse container is already running.${NC}"
    else
        echo "Starting lighthouse container..."
        if docker start lighthouse; then
            echo -e "${GREEN}Lighthouse container started successfully.${NC}"
        else
            echo -e "${RED}Failed to start lighthouse container. Check logs with: docker logs lighthouse${NC}"
            if [ "$SHOW_LOGS" = true ]; then
                echo -e "${YELLOW}Showing lighthouse logs:${NC}"
                docker logs --tail 50 lighthouse
            fi
            exit 1
        fi
    fi
else
    echo -e "${RED}Lighthouse container not found. Run install.sh to set up the node.${NC}"
    exit 1
fi

# Verify all containers are running
echo -e "${YELLOW}Verifying containers are running...${NC}"
if container_running go-pulse && container_running lighthouse; then
    echo -e "${GREEN}All PulseChain node containers are now running.${NC}"
else
    echo -e "${RED}Some containers failed to start. Check logs for details.${NC}"
    if [ "$SHOW_LOGS" = true ]; then
        echo -e "${YELLOW}Showing container logs:${NC}"
        echo -e "${YELLOW}--- go-pulse logs ---${NC}"
        docker logs --tail 50 go-pulse
        echo -e "${YELLOW}--- lighthouse logs ---${NC}"
        docker logs --tail 50 lighthouse
    else
        echo "View logs using: docker logs go-pulse or docker logs lighthouse"
    fi
fi

echo ""
echo -e "${GREEN}Restart process completed!${NC}"
echo "To check node status, use: ./check-node.sh" 