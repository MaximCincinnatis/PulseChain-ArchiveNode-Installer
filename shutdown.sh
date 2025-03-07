#!/bin/bash

# PulseChain Archive Node - Graceful Shutdown
# This script properly shuts down the PulseChain Archive Node containers
# It gracefully terminates the containers with configurable timeouts
# and provides detailed status feedback

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Handle script interruptions gracefully
# This stops the script if user presses Ctrl+C and shows a warning message
trap 'echo -e "${RED}Shutdown interrupted. Some containers may still be running.${NC}"; exit 1' INT TERM

# Default configuration values
FORCE=false
LIGHTHOUSE_TIMEOUT=60
GOPULSE_TIMEOUT=120

# Display help message
show_help() {
    echo "Usage: $0 [OPTIONS] [LIGHTHOUSE_TIMEOUT] [GOPULSE_TIMEOUT]"
    echo "Gracefully shut down PulseChain Archive Node containers."
    echo ""
    echo "Options:"
    echo "  --force            Force kill containers if graceful shutdown fails"
    echo "  --help, -h         Display this help message and exit"
    echo ""
    echo "Arguments:"
    echo "  LIGHTHOUSE_TIMEOUT Seconds to wait for lighthouse shutdown (default: 60)"
    echo "  GOPULSE_TIMEOUT    Seconds to wait for go-pulse shutdown (default: 120)"
    echo ""
    echo "Examples:"
    echo "  $0                  Shutdown with default timeouts"
    echo "  $0 --force          Enable force mode with default timeouts"
    echo "  $0 30 90            Use 30s timeout for lighthouse and 90s for go-pulse"
    echo "  $0 --force 30 90    Force mode with custom timeouts"
    exit 0
}

# Process command line arguments with improved parsing
LIGHTHOUSE_TIMEOUT_SET=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            # If argument is a positive integer, use it as a timeout value
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                if [ "$LIGHTHOUSE_TIMEOUT_SET" = false ]; then
                    LIGHTHOUSE_TIMEOUT=$1
                    LIGHTHOUSE_TIMEOUT_SET=true
                else
                    GOPULSE_TIMEOUT=$1
                fi
            else
                echo -e "${RED}Error: Invalid argument '$1'. Expected number or --force/--help.${NC}"
                echo "Run '$0 --help' for usage information."
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate timeout values to ensure they are positive integers
if ! [[ "$LIGHTHOUSE_TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: LIGHTHOUSE_TIMEOUT must be a positive integer (got '$LIGHTHOUSE_TIMEOUT'). Using default of 60.${NC}"
    LIGHTHOUSE_TIMEOUT=60
fi

if ! [[ "$GOPULSE_TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: GOPULSE_TIMEOUT must be a positive integer (got '$GOPULSE_TIMEOUT'). Using default of 120.${NC}"
    GOPULSE_TIMEOUT=120
fi

# Print banner
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}    PulseChain Archive Node - Graceful Shutdown   ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo -e "Using timeouts: Lighthouse=${LIGHTHOUSE_TIMEOUT}s, Go-Pulse=${GOPULSE_TIMEOUT}s"
if [ "$FORCE" = true ]; then
    echo -e "${YELLOW}Force mode enabled - will kill containers if graceful shutdown fails${NC}"
fi

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

# Function to force stop a container if needed
force_stop_container() {
    local container_name=$1
    echo -e "${YELLOW}Force stopping ${container_name} container...${NC}"
    if docker kill "${container_name}" >/dev/null 2>&1; then
        echo -e "${GREEN}${container_name} container force stopped.${NC}"
        return 0
    else
        echo -e "${RED}Failed to force stop ${container_name} container. Manual intervention may be required.${NC}"
        echo -e "${YELLOW}You may need to run 'docker kill ${container_name}' manually after resolving any issues.${NC}"
        return 1
    fi
}

# Gracefully stop containers with timeout
echo -e "${YELLOW}Starting graceful shutdown sequence...${NC}"
echo ""  # Add spacing for better readability

# First stop the lighthouse (beacon chain) container
if container_running lighthouse; then
    echo "Stopping lighthouse container (with ${LIGHTHOUSE_TIMEOUT} second timeout)..."
    if docker stop --time="${LIGHTHOUSE_TIMEOUT}" lighthouse >/dev/null 2>&1; then
        echo -e "${GREEN}Lighthouse container stopped successfully.${NC}"
    else
        echo -e "${RED}Failed to stop lighthouse container gracefully.${NC}"
        # Try force stop if enabled
        if [ "$FORCE" = true ]; then
            if ! force_stop_container lighthouse; then
                echo -e "${RED}Proceeding with caution due to force stop failure.${NC}"
            fi
        fi
    fi
elif container_exists lighthouse; then
    echo -e "${YELLOW}Lighthouse container already stopped.${NC}"
else
    echo -e "${RED}Lighthouse container not found.${NC}"
fi

# Then stop the go-pulse (execution layer) container
if container_running go-pulse; then
    echo "Stopping go-pulse container (with ${GOPULSE_TIMEOUT} second timeout)..."
    if docker stop --time="${GOPULSE_TIMEOUT}" go-pulse >/dev/null 2>&1; then
        echo -e "${GREEN}Go-pulse container stopped successfully.${NC}"
    else
        echo -e "${RED}Failed to stop go-pulse container gracefully.${NC}"
        # Try force stop if enabled
        if [ "$FORCE" = true ]; then
            if ! force_stop_container go-pulse; then
                echo -e "${RED}Proceeding with caution due to force stop failure.${NC}"
            fi
        fi
    fi
elif container_exists go-pulse; then
    echo -e "${YELLOW}Go-pulse container already stopped.${NC}"
else
    echo -e "${RED}Go-pulse container not found.${NC}"
fi

# Status summary table
echo ""  # Add spacing for better readability
echo -e "${YELLOW}Container Status:${NC}"
printf "  %-15s: %s\n" "lighthouse" "$(container_running lighthouse && echo -e "${RED}Running${NC}" || echo -e "${GREEN}Stopped${NC}")"
printf "  %-15s: %s\n" "go-pulse" "$(container_running go-pulse && echo -e "${RED}Running${NC}" || echo -e "${GREEN}Stopped${NC}")"

# Verify all containers are stopped
if container_running lighthouse || container_running go-pulse; then
    echo -e "${RED}Warning: Some containers are still running. Shutdown may not be complete.${NC}"
    if [ "$FORCE" != true ]; then
        echo -e "${YELLOW}Tip: You can use --force to forcefully stop unresponsive containers:${NC}"
        echo -e "     ./shutdown.sh --force"
    fi
else
    echo -e "${GREEN}All PulseChain node containers have been gracefully stopped.${NC}"
fi

echo ""  # Add spacing for better readability
echo -e "${GREEN}Shutdown process completed!${NC}"
echo "To restart the node, use: ./restart.sh" 