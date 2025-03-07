#!/bin/bash

# PulseChain Archive Node Installer Upgrade
# This script updates the installer to the latest version

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# GitHub repository URL
REPO_URL="https://raw.githubusercontent.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer/main"

echo -e "${GREEN}PulseChain Archive Node - Installer Upgrade${NC}"
echo -e "${YELLOW}This script will check for updates to the PulseChain Archive Node installer.${NC}"

# Get current version
if [ -f "VERSION" ]; then
    CURRENT_VERSION=$(cat VERSION)
    echo -e "Current version: ${GREEN}$CURRENT_VERSION${NC}"
else
    CURRENT_VERSION="0.0.0"
    echo -e "${YELLOW}No version file found. Assuming initial installation.${NC}"
fi

# Get latest version from GitHub
echo "Checking for updates..."
LATEST_VERSION=$(curl -sSL ${REPO_URL}/VERSION)

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Error: Could not retrieve the latest version.${NC}"
    echo "Please check your internet connection or the repository URL."
    exit 1
fi

echo -e "Latest version: ${GREEN}$LATEST_VERSION${NC}"

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo -e "${GREEN}You are already running the latest version!${NC}"
    
    # Ask if they want to force update
    read -p "Force update anyway? (y/N): " -r FORCE_UPDATE
    if [[ ! $FORCE_UPDATE =~ ^[Yy]$ ]]; then
        echo "Update canceled."
        exit 0
    fi
fi

# Backup existing files
echo "Creating backup of current installation..."
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup all script files
for file in install.sh install-quick.sh check-node.sh VERSION; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/"
        echo "Backed up $file"
    fi
done

echo "Backup created in $BACKUP_DIR"

# Download latest files
echo "Downloading latest installer files..."

# List of files to download
FILES=("install.sh" "install-quick.sh" "check-node.sh" "VERSION" "README.md")

for file in "${FILES[@]}"; do
    echo "Downloading $file..."
    curl -sSL ${REPO_URL}/"$file" -o "$file"
    
    # Make scripts executable
    if [[ $file == *.sh ]]; then
        chmod +x "$file"
        echo "Made $file executable"
    fi
done

echo -e "${GREEN}Upgrade completed successfully!${NC}"
echo "New version: $LATEST_VERSION"
echo -e "\nTo run the updated installer, use: ./install.sh" 