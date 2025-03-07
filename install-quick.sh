#!/bin/bash

# Quick installer for PulseChain Archive Node
# This script downloads and runs the full installer

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}PulseChain Archive Node - Quick Installer${NC}"
echo -e "${YELLOW}This script will download and run the PulseChain Archive Node installer.${NC}"

# Check for curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    echo -e "${YELLOW}Please install curl (e.g., 'sudo apt install curl' on Ubuntu)${NC}"
    exit 1
fi

# GitHub repository URL
REPO_URL="https://raw.githubusercontent.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer/main"

echo "Downloading installer..."

# Download the installer script with error handling
if ! curl -sSL --max-time 30 "${REPO_URL}/install.sh" -o install.sh; then
    echo -e "${RED}Error: Failed to download installer.${NC}"
    echo -e "${YELLOW}Check your internet connection or the repository URL.${NC}"
    exit 1
fi

# Verify download
if [ ! -s install.sh ]; then
    echo -e "${RED}Error: Downloaded installer is empty or missing.${NC}"
    rm -f install.sh
    exit 1
fi

# Make it executable
chmod +x install.sh

echo "Installer downloaded successfully."
echo -e "${GREEN}Starting installation...${NC}"

# Run the installer and capture its exit status
if ./install.sh; then
    echo -e "${GREEN}Installation process completed successfully!${NC}"
    # Clean up only on success
    rm -f install.sh
else
    echo -e "${RED}Installation failed.${NC}"
    echo -e "${YELLOW}The installer script (install.sh) has been left in place for debugging.${NC}"
    exit 1
fi 