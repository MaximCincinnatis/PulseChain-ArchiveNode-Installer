#!/bin/bash

# Shell script to push to GitHub
# This script handles pushing your PulseChain Archive Node Installer to GitHub

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

# Display banner
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}    PulseChain Archive Node - GitHub Push Tool    ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

# Function to check git status
check_git_status() {
    echo -e "${YELLOW}Checking Git status...${NC}"
    git status
    echo ""
}

# Function to push to GitHub
push_to_github() {
    local token="$1"
    
    echo -e "${YELLOW}Attempting to push to GitHub...${NC}"
    
    # Set the remote URL with the token
    local remote_url="https://${token}@github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git"
    git remote set-url origin "$remote_url"
    
    # Push to GitHub
    git push -u origin master
    
    # Reset the URL to not contain the token (for security)
    git remote set-url origin "https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git"
    
    echo -e "${GREEN}Push completed!${NC}"
}

# Main script execution
{
    # Check current git status
    check_git_status
    
    # Ask for GitHub Personal Access Token
    echo -e "${YELLOW}To push to GitHub, you need a Personal Access Token.${NC}"
    echo -e "${YELLOW}You can create one at: https://github.com/settings/tokens${NC}"
    echo -e "${YELLOW}Ensure it has 'repo' permissions.${NC}"
    echo ""
    
    # Read token securely
    read -sp "Enter your GitHub Personal Access Token: " token
    echo ""
    
    # Push to GitHub
    push_to_github "$token"
    
    # Clean up - zero out the token variable
    token="xxxxxxxxxxxxxxxxxxxx"
    unset token
    
    echo ""
    echo -e "${GREEN}GitHub push completed successfully!${NC}"
    echo -e "${GREEN}Visit your repository at: https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer${NC}"
    
} || {
    echo -e "${RED}An error occurred.${NC}"
    echo ""
    echo -e "${YELLOW}Manual Push Instructions:${NC}"
    echo -e "${YELLOW}1. Open a terminal outside of Cursor${NC}"
    echo -e "${YELLOW}2. Navigate to: $(pwd)${NC}"
    echo -e "${YELLOW}3. Run: git push -u origin master${NC}"
    echo -e "${YELLOW}4. Enter your GitHub credentials when prompted${NC}"
} 