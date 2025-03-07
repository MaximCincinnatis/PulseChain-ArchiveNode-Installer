#!/bin/bash

# PulseChain Archive Node - Script Compatibility Patcher
# This script updates all existing scripts to use the standardized permission system

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}    PulseChain Archive Node - Script Patcher     ${NC}"
echo -e "${GREEN}=================================================${NC}"

# Get the current installation directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if the node_env.sh config file exists
if [ ! -f "$INSTALL_DIR/node_env.sh" ]; then
    echo -e "${RED}Error: node_env.sh configuration file not found.${NC}"
    echo -e "${YELLOW}Please run the installer first to create this file.${NC}"
    exit 1
fi

# List of scripts to patch
SCRIPTS=(
    "restart.sh"
    "shutdown.sh"
    "check-node.sh"
    "monitor-node.sh"
    "monitor-dashboard.sh"
    "edit-parameters.sh"
    "auto-recovery.sh"
    "upgrade.sh"
)

# Create the backup directory
BACKUP_DIR="$INSTALL_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo -e "${GREEN}Backup directory created: $BACKUP_DIR${NC}"

# Function to patch a script
patch_script() {
    local script="$1"
    
    # Skip if script doesn't exist
    if [ ! -f "$INSTALL_DIR/$script" ]; then
        echo -e "${YELLOW}Script $script not found, skipping.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Patching $script...${NC}"
    
    # Create backup
    cp "$INSTALL_DIR/$script" "$BACKUP_DIR/$script.bak"
    
    # Check if already patched
    if grep -q "source.*node_env.sh" "$INSTALL_DIR/$script"; then
        echo -e "${GREEN}Script $script is already patched.${NC}"
        return
    fi
    
    # Add sourcing of node_env.sh after the shebang
    sed -i "1a\\
# Source common environment settings\\
SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"\\
source \"\$SCRIPT_DIR/node_env.sh\" || { echo \"Error: node_env.sh not found\"; exit 1; }" "$INSTALL_DIR/$script"
    
    # Replace direct sudo docker commands with docker_cmd
    sed -i 's/sudo docker /docker_cmd /g' "$INSTALL_DIR/$script"
    sed -i 's/docker /docker_cmd /g' "$INSTALL_DIR/$script"
    
    # Add line to ensure docker_cmd function is defined even if sourcing failed
    sed -i "3a\\
# Fallback docker command function in case sourcing failed\\
[ -z \"\$(declare -f docker_cmd)\" ] && docker_cmd() { sudo docker \"\$@\"; }" "$INSTALL_DIR/$script"
    
    echo -e "${GREEN}Script $script successfully patched.${NC}"
}

# Loop through all scripts and patch them
for script in "${SCRIPTS[@]}"; do
    patch_script "$script"
done

# Update file permissions to standard
for script in "${SCRIPTS[@]}" "node_env.sh" "patch-scripts.sh"; do
    if [ -f "$INSTALL_DIR/$script" ]; then
        chmod 755 "$INSTALL_DIR/$script"
        echo -e "${GREEN}Updated permissions for $script${NC}"
    fi
done

echo -e "${GREEN}Script patching completed!${NC}"
echo -e "${YELLOW}Original script backups are in $BACKUP_DIR${NC}"
echo -e "${YELLOW}Note: If you experience issues with any script, you can restore from the backup.${NC}" 