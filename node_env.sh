#!/bin/bash

# PulseChain Archive Node - Environment Configuration
# This file contains common environment variables and functions 
# used across all PulseChain node management scripts

# Version Information
export NODE_VERSION="1.0.0"

# ===================== User and Permission Settings =====================
# User & Group Configuration
export NODE_USER="$USER"
export NODE_GROUP="pulsechain"

# Docker command function - handles sudo if needed
# Usage: docker_cmd command [args...]
docker_cmd() {
    if [ "$DOCKER_USE_SUDO" = true ]; then
        sudo docker "$@"
    else
        docker "$@"
    fi
}
export DOCKER_USE_SUDO=true

# ===================== Path Configuration =====================
# Default data directory
export DEFAULT_DATA_DIR="/blockchain"
# Use existing DATA_DIR if set (from the parent script), otherwise use DEFAULT_DATA_DIR
# Note: Scripts should set DATA_DIR before sourcing this file if they need a custom path
export DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"

# ===================== Container Configuration =====================
# Container names
export GO_PULSE_CONTAINER="go-pulse"
export LIGHTHOUSE_CONTAINER="lighthouse"

# ===================== Network Configuration =====================
# Network settings
export RPC_PORT=8545
export RPC_URL="http://localhost:${RPC_PORT}"
export CONSENSUS_PORT=5052
export CONSENSUS_URL="http://localhost:${CONSENSUS_PORT}"

# ===================== Monitoring Thresholds =====================
# Thresholds for monitoring and auto-recovery
export SYNC_THRESHOLD=1800  # 30 minutes in seconds - time before considering sync stuck
export PEER_THRESHOLD=3     # Minimum acceptable number of peers
export DISK_WARNING=90      # Disk usage percentage for warning
export DISK_CRITICAL=95     # Disk usage percentage for critical warning

# ===================== Utility Functions =====================
# Color definitions for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Check for dependencies but don't install - installation is handled by install.sh
check_dependencies() {
    local missing_deps=()
    
    # Check each required dependency - align with what install.sh installs
    for cmd in docker bc awk grep cut jq; do
        if ! command -v $cmd &> /dev/null; then
            # Special case for docker which might be installed as docker.io
            if [ "$cmd" = "docker" ] && command -v docker.io &> /dev/null; then
                continue
            fi
            missing_deps+=("$cmd")
        fi
    done
    
    # If we found missing dependencies, inform but don't install
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: Missing dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please run the main installer script (install.sh) first to ensure all dependencies are installed.${NC}"
        return 1
    fi
    
    # If Docker exists but isn't running, inform
    if command -v docker &> /dev/null && ! docker info &>/dev/null; then
        echo -e "${YELLOW}Warning: Docker is installed but not running or you don't have permission to use it.${NC}"
        echo -e "${YELLOW}Please ensure Docker is running with: sudo systemctl start docker${NC}"
        echo -e "${YELLOW}And that you have proper permissions to use Docker.${NC}"
        return 1
    fi
    
    return 0
}

# Run a non-intrusive dependency check (doesn't try to install anything)
# This aligns with the install.sh approach where installation is centralized
check_dependencies || {
    echo -e "${YELLOW}Some required dependencies are missing or not properly configured.${NC}"
    echo -e "${YELLOW}Running scripts may fail until install.sh has completed successfully.${NC}"
}

# Function to format time in a human-readable way
format_time() {
    local seconds=$1
    
    # Use basic calculation if bc is missing
    if ! command -v bc &> /dev/null; then
        echo "${seconds}s"
        return
    fi
    
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

# Function to format disk space in a human-readable way
format_disk_space() {
    local size=$1
    
    # Use basic format if bc is missing
    if ! command -v bc &> /dev/null; then
        echo "${size} GB"
        return
    fi
    
    if (( $(echo "$size > 1000" | bc -l) )); then
        printf "%.2f TB" "$(echo "$size/1000" | bc -l)"
    else
        printf "%.2f GB" "$size"
    fi
} 