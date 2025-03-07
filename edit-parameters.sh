#!/bin/bash

# PulseChain Archive Node - Parameter Editor
# This script allows editing parameters for your PulseChain node

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Documentation URL
DOCS_URL="https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer"
OPTIONS_DOC_URL="$DOCS_URL/blob/main/node-options.md"

# Print banner
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}    PulseChain Archive Node - Parameter Editor    ${NC}"
echo -e "${GREEN}=================================================${NC}"

# Docker integration check
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo -e "${YELLOW}Please install Docker before continuing.${NC}"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo -e "${RED}Error: Docker is not running or you don't have sufficient permissions${NC}"
    echo -e "${YELLOW}Please start Docker or run this script with appropriate permissions.${NC}"
    exit 1
fi

# Function to get data directory
get_data_dir() {
    # Check common locations
    potential_dirs=("/blockchain" "/var/lib/blockchain" "$HOME/blockchain")
    
    for dir in "${potential_dirs[@]}"; do
        if [ -f "$dir/node_config.env" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    # If not found, ask user
    echo -e "${YELLOW}Could not find configuration file automatically.${NC}"
    read -p "Enter your blockchain data directory: " -r user_dir
    
    if [ -f "$user_dir/node_config.env" ]; then
        echo "$user_dir"
    else
        echo -e "${RED}No configuration file found at $user_dir/node_config.env${NC}"
        echo -e "${YELLOW}Creating a new configuration file...${NC}"
        
        # Create directory if it doesn't exist
        mkdir -p "$user_dir"
        
        # Create default config
        cat > "$user_dir/node_config.env" << EOL
MAX_PEERS=50
MAX_PENDING_PEERS=100
CACHE_SIZE=4096
EOL
        echo "$user_dir"
    fi
}

# Load current configuration
DATA_DIR=$(get_data_dir)
CONFIG_FILE="$DATA_DIR/node_config.env"

echo -e "${GREEN}Using configuration file: $CONFIG_FILE${NC}"

# Check if we have write permissions
if [ ! -w "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: No write permission for $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Try running with sudo or fixing permissions${NC}"
    exit 1
fi

# Source the existing configuration
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    echo -e "${GREEN}Loaded existing configuration.${NC}"
else
    echo -e "${RED}Error: Configuration file not found.${NC}"
    exit 1
fi

# Show current container status
echo -e "\n${YELLOW}Container Status:${NC}"
for container in go-pulse lighthouse; do
    if [ "$(docker ps -q -f name=$container)" ]; then
        echo -e "${GREEN}✓ $container is running${NC}"
    else
        echo -e "${RED}✗ $container is not running${NC}"
    fi
done

# Show current values
echo -e "\n${YELLOW}Current Node Parameters:${NC}"
echo "1. MAX_PEERS = $MAX_PEERS (Maximum number of network peers)"
echo "2. MAX_PENDING_PEERS = $MAX_PENDING_PEERS (Maximum pending connection attempts)"
echo "3. CACHE_SIZE = $CACHE_SIZE (Memory allocated to caching in MB)"

# Get user input for which parameter to edit
echo -e "\n${GREEN}Which parameter would you like to edit?${NC}"
echo "Enter the number, or 'a' for all, or 'q' to quit:"
read -p "> " -r choice

case "$choice" in
    1)
        read -p "Enter new value for MAX_PEERS (current: $MAX_PEERS): " -r new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            if [ "$new_value" -lt 10 ] || [ "$new_value" -gt 1000 ]; then
                echo -e "${RED}Warning: Recommended MAX_PEERS range is 10-1000.${NC}"
                read -p "Are you sure you want to use $new_value? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    MAX_PEERS=$new_value
                    echo -e "${GREEN}MAX_PEERS updated to $MAX_PEERS${NC}"
                else
                    echo -e "${YELLOW}Keeping existing value.${NC}"
                fi
            else
                MAX_PEERS=$new_value
                echo -e "${GREEN}MAX_PEERS updated to $MAX_PEERS${NC}"
            fi
        else
            echo -e "${RED}Invalid input. Using existing value.${NC}"
        fi
        ;;
    2)
        read -p "Enter new value for MAX_PENDING_PEERS (current: $MAX_PENDING_PEERS): " -r new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            if [ "$new_value" -lt 5 ] || [ "$new_value" -gt 500 ]; then
                echo -e "${RED}Warning: Recommended MAX_PENDING_PEERS range is 5-500.${NC}"
                read -p "Are you sure you want to use $new_value? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    MAX_PENDING_PEERS=$new_value
                    echo -e "${GREEN}MAX_PENDING_PEERS updated to $MAX_PENDING_PEERS${NC}"
                else
                    echo -e "${YELLOW}Keeping existing value.${NC}"
                fi
            else
                MAX_PENDING_PEERS=$new_value
                echo -e "${GREEN}MAX_PENDING_PEERS updated to $MAX_PENDING_PEERS${NC}"
            fi
        else
            echo -e "${RED}Invalid input. Using existing value.${NC}"
        fi
        ;;
    3)
        read -p "Enter new value for CACHE_SIZE (current: $CACHE_SIZE): " -r new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            if [ "$new_value" -lt 1024 ] || [ "$new_value" -gt 16384 ]; then
                echo -e "${RED}Warning: Recommended CACHE_SIZE range is 1024-16384 MB.${NC}"
                read -p "Are you sure you want to use $new_value? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    CACHE_SIZE=$new_value
                    echo -e "${GREEN}CACHE_SIZE updated to $CACHE_SIZE${NC}"
                else
                    echo -e "${YELLOW}Keeping existing value.${NC}"
                fi
            else
                CACHE_SIZE=$new_value
                echo -e "${GREEN}CACHE_SIZE updated to $CACHE_SIZE${NC}"
            fi
        else
            echo -e "${RED}Invalid input. Using existing value.${NC}"
        fi
        ;;
    a|A)
        read -p "Enter new value for MAX_PEERS (current: $MAX_PEERS): " -r new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            if [ "$new_value" -lt 10 ] || [ "$new_value" -gt 1000 ]; then
                echo -e "${RED}Warning: Recommended MAX_PEERS range is 10-1000.${NC}"
                read -p "Are you sure you want to use $new_value? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    MAX_PEERS=$new_value
                    echo -e "${GREEN}MAX_PEERS updated to $MAX_PEERS${NC}"
                else
                    echo -e "${YELLOW}Keeping existing value.${NC}"
                fi
            else
                MAX_PEERS=$new_value
                echo -e "${GREEN}MAX_PEERS updated to $MAX_PEERS${NC}"
            fi
        else
            echo -e "${RED}Invalid input. Using existing value.${NC}"
        fi
        
        read -p "Enter new value for MAX_PENDING_PEERS (current: $MAX_PENDING_PEERS): " -r new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            if [ "$new_value" -lt 5 ] || [ "$new_value" -gt 500 ]; then
                echo -e "${RED}Warning: Recommended MAX_PENDING_PEERS range is 5-500.${NC}"
                read -p "Are you sure you want to use $new_value? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    MAX_PENDING_PEERS=$new_value
                    echo -e "${GREEN}MAX_PENDING_PEERS updated to $MAX_PENDING_PEERS${NC}"
                else
                    echo -e "${YELLOW}Keeping existing value.${NC}"
                fi
            else
                MAX_PENDING_PEERS=$new_value
                echo -e "${GREEN}MAX_PENDING_PEERS updated to $MAX_PENDING_PEERS${NC}"
            fi
        else
            echo -e "${RED}Invalid input. Using existing value.${NC}"
        fi
        
        read -p "Enter new value for CACHE_SIZE (current: $CACHE_SIZE): " -r new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            if [ "$new_value" -lt 1024 ] || [ "$new_value" -gt 16384 ]; then
                echo -e "${RED}Warning: Recommended CACHE_SIZE range is 1024-16384 MB.${NC}"
                read -p "Are you sure you want to use $new_value? (y/N): " -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    CACHE_SIZE=$new_value
                    echo -e "${GREEN}CACHE_SIZE updated to $CACHE_SIZE${NC}"
                else
                    echo -e "${YELLOW}Keeping existing value.${NC}"
                fi
            else
                CACHE_SIZE=$new_value
                echo -e "${GREEN}CACHE_SIZE updated to $CACHE_SIZE${NC}"
            fi
        else
            echo -e "${RED}Invalid input. Using existing value.${NC}"
        fi
        ;;
    q|Q)
        echo -e "${YELLOW}Exiting without changes.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice.${NC}"
        exit 1
        ;;
esac

# Create backup of original configuration
echo -e "\n${YELLOW}Creating backup of original configuration...${NC}"
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d_%H%M%S)"

# Save updated configuration
echo -e "\n${GREEN}Saving configuration...${NC}"
# Trim whitespace from all variables to prevent configuration issues
trim() {
    local var="$*"
    # Remove leading and trailing whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

MAX_PEERS=$(trim "$MAX_PEERS")
MAX_PENDING_PEERS=$(trim "$MAX_PENDING_PEERS")
CACHE_SIZE=$(trim "$CACHE_SIZE")

cat > "$CONFIG_FILE" << EOL
MAX_PEERS=$MAX_PEERS
MAX_PENDING_PEERS=$MAX_PENDING_PEERS
CACHE_SIZE=$CACHE_SIZE
EOL

echo -e "${GREEN}Configuration saved.${NC}"
echo -e "${YELLOW}Note: You'll need to restart your node for changes to take effect.${NC}"

# Offer to restart the node automatically
read -p "Restart node now to apply changes? (y/N): " -r restart
if [[ "$restart" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Restarting node...${NC}"
    if [ -f "./shutdown.sh" ] && [ -f "./restart.sh" ]; then
        ./shutdown.sh && ./restart.sh
    else
        echo -e "${RED}Error: shutdown.sh or restart.sh not found.${NC}"
        echo "To restart your node manually, run: ./shutdown.sh && ./restart.sh"
    fi
else
    echo "To restart your node later, run: ./shutdown.sh && ./restart.sh"
fi

# Show advanced options documentation
echo -e "\n${GREEN}Would you like to see the full list of available node parameters?${NC}"
read -p "View documentation? (y/N): " -r view_docs

if [[ "$view_docs" =~ ^[Yy]$ ]]; then
    if [ -f "node-options.md" ]; then
        more node-options.md
    else
        echo -e "${RED}Documentation file not found.${NC}"
        echo -e "${YELLOW}Please visit $OPTIONS_DOC_URL for full documentation.${NC}"
    fi
fi

echo -e "\n${GREEN}Parameter editing completed!${NC}" 