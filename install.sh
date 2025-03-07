#!/bin/bash

# PulseChain Archive Node Installer
# Created by Maxim Broadcast - March 06, 2023
# This script installs and configures a PulseChain Archive Node on Ubuntu

# Exit on any error
set -e

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Print banner
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}    PulseChain Archive Node Installer            ${NC}"
echo -e "${GREEN}    Version 1.0.0                               ${NC}"
echo -e "${GREEN}=================================================${NC}"

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${RED}Error: This script is designed for Ubuntu.${NC}"
    exit 1
fi

# Verify sudo privileges
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Sudo privileges required. Please enter your password if prompted.${NC}"
    if ! sudo -v; then
        echo -e "${RED}Error: This script requires sudo privileges.${NC}"
        exit 1
    fi
fi

# Update package repositories
echo -e "${YELLOW}Checking for system updates...${NC}"
if ! sudo apt update -q; then
    echo -e "${RED}Warning: Failed to update package repositories.${NC}"
    read -p "Continue anyway? (y/N): " -r UPDATE_CONTINUE
    if [[ ! $UPDATE_CONTINUE =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation aborted.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Package repositories updated successfully.${NC}"
fi

# Check for curl - critical for downloads
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}curl not found. This is required for downloading components.${NC}"
    read -p "Install curl now? (Y/n): " -r INSTALL_CURL
    if [[ ! $INSTALL_CURL =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installing curl...${NC}"
        if sudo apt install -y curl; then
            echo -e "${GREEN}curl installed successfully.${NC}"
        else
            echo -e "${RED}Failed to install curl. This is required to continue.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}curl is required for installation. Aborting.${NC}"
        exit 1
    fi
fi

# ----- PERMISSIONS AND SECURITY MANAGEMENT SYSTEM -----
# This section sets up dedicated user groups and permissions for secure node operation.
# It creates a 'pulsechain' group and adds the current user to it for better access control.
# It also checks Docker permissions and configures the installer to use sudo if needed.
echo -e "${GREEN}Setting up permissions and security...${NC}"

# Define standard variables for permissions
NODE_USER="$USER"           # Current user will own the installation
NODE_GROUP="pulsechain"     # Dedicated group for node management
DEFAULT_DATA_DIR="/blockchain"
DOCKER_USE_SUDO=true        # Whether to prepend sudo to docker commands

# Function to create a dedicated group for node management
# This improves security by controlling who can manage node operations
setup_node_permissions() {
    echo -e "${YELLOW}Setting up dedicated 'pulsechain' group for secure node management...${NC}"
    
    # Create the pulsechain group if it doesn't exist
    # This group will have specific permissions for node operation
    if ! getent group "$NODE_GROUP" >/dev/null; then
        sudo groupadd "$NODE_GROUP"
        echo -e "${GREEN}Created $NODE_GROUP group.${NC}"
    else
        echo -e "${GREEN}Group $NODE_GROUP already exists.${NC}"
    fi
    
    # Add current user to the pulsechain group
    # This gives the current user the permissions needed to manage the node
    if ! groups "$NODE_USER" | grep -q "\b$NODE_GROUP\b"; then
        sudo usermod -aG "$NODE_GROUP" "$NODE_USER"
        echo -e "${GREEN}Added user $NODE_USER to $NODE_GROUP group.${NC}"
        echo -e "${YELLOW}Note: You'll need to log out and back in for this to take full effect.${NC}"
        echo -e "${YELLOW}However, the installation will proceed correctly.${NC}"
    else
        echo -e "${GREEN}User $NODE_USER is already in group $NODE_GROUP.${NC}"
    fi
    
    # Check Docker group membership and Docker socket permissions
    # This determines whether we need to use sudo for Docker commands
    if [ -S /var/run/docker.sock ]; then
        DOCKER_SOCKET_GROUP=$(stat -c "%G" /var/run/docker.sock)
        
        if [ "$DOCKER_SOCKET_GROUP" = "docker" ]; then
            # If the Docker socket is owned by the 'docker' group, check if user is in that group
            if groups "$NODE_USER" | grep -q "\bdocker\b"; then
                echo -e "${GREEN}User $NODE_USER is in the docker group.${NC}"
                DOCKER_USE_SUDO=false  # No need for sudo with docker
            else
                echo -e "${YELLOW}User $NODE_USER is not in the docker group.${NC}"
                read -p "Add to docker group? This allows running docker without sudo (Y/n): " -r ADD_DOCKER
                if [[ ! $ADD_DOCKER =~ ^[Nn]$ ]]; then
                    sudo usermod -aG docker "$NODE_USER"
                    echo -e "${GREEN}Added user $NODE_USER to docker group.${NC}"
                    echo -e "${YELLOW}You'll need to log out and back in for this to take effect.${NC}"
                    echo -e "${YELLOW}For now, we'll use sudo with docker commands.${NC}"
                else
                    echo -e "${YELLOW}Continuing without adding to docker group. Will use sudo for docker commands.${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}Docker socket is owned by group $DOCKER_SOCKET_GROUP, not 'docker'.${NC}"
            echo -e "${YELLOW}Will use sudo for docker commands.${NC}"
        fi
    else
        echo -e "${YELLOW}Docker socket not found. Is Docker installed?${NC}"
        echo -e "${YELLOW}Will use sudo for docker commands.${NC}"
    fi
}

# Function to standardize docker command with or without sudo
docker_cmd() {
    if [ "$DOCKER_USE_SUDO" = true ]; then
        sudo docker "$@"
    else
        docker "$@"
    fi
}

# Function to apply standard permissions to a directory
apply_standard_permissions() {
    local dir="$1"
    local type="$2"  # "data", "logs", "scripts", "config"
    
    echo -e "${YELLOW}Setting up secure permissions for $dir ($type)...${NC}"
    
    # Create directory if it doesn't exist
    if [ ! -d "$dir" ]; then
        if ! sudo mkdir -p "$dir"; then
            echo -e "${RED}Error: Failed to create directory $dir${NC}"
            echo -e "${YELLOW}Check if you have sufficient permissions or disk space${NC}"
            return 1
        fi
    fi
    
    # Set appropriate permissions based on directory type
    case "$type" in
        "data")
            # Data directories need to be accessible by Docker containers
            sudo chown -R root:"$NODE_GROUP" "$dir"
            sudo chmod -R 770 "$dir"  # rwxrwx---
            ;;
        "logs")
            # Log directories need to be writable but more restricted
            sudo chown -R "$NODE_USER":"$NODE_GROUP" "$dir"
            sudo chmod -R 750 "$dir"  # rwxr-x---
            ;;
        "scripts")
            # Scripts need to be executable but not world-writable
            sudo chown -R "$NODE_USER":"$NODE_GROUP" "$dir"
            sudo chmod -R 755 "$dir"  # rwxr-xr-x
            # Make all .sh files explicitly executable
            find "$dir" -name "*.sh" -exec sudo chmod 755 {} \;
            ;;
        "config")
            # Config files need tight permissions
            sudo chown -R "$NODE_USER":"$NODE_GROUP" "$dir"
            sudo chmod -R 750 "$dir"  # rwxr-x---
            # Ensure sensitive files are properly restricted
            find "$dir" \( -name "*.env" -o -name "*.key" -o -name "*.hex" \) -exec sudo chmod 640 {} \;
            ;;
        *)
            # Default case
            sudo chown -R "$NODE_USER":"$NODE_GROUP" "$dir"
            sudo chmod -R 750 "$dir"  # rwxr-x---
            ;;
    esac
    
    echo -e "${GREEN}Permissions set for $dir${NC}"
}

# Function to set up firewall rules
setup_firewall() {
    local go_pulse_p2p="$1"
    local lighthouse_p2p="$2"
    
    # Check if UFW is installed and active
    if command -v ufw &>/dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            echo -e "${YELLOW}UFW firewall is active. Setting up rules...${NC}"
            
            echo -e "${YELLOW}Would you like to automatically open required ports in the firewall?${NC}"
            read -p "Open ports $go_pulse_p2p and $lighthouse_p2p now? (Y/n): " -r OPEN_PORTS
            
            if [[ ! $OPEN_PORTS =~ ^[Nn]$ ]]; then
                # Open required ports for go-pulse and lighthouse P2P
                sudo ufw allow "$go_pulse_p2p"/tcp comment 'PulseChain go-pulse P2P'
                sudo ufw allow "$go_pulse_p2p"/udp comment 'PulseChain go-pulse P2P'
                sudo ufw allow "$lighthouse_p2p"/tcp comment 'PulseChain lighthouse P2P'
                sudo ufw allow "$lighthouse_p2p"/udp comment 'PulseChain lighthouse P2P'
                echo -e "${GREEN}Firewall rules added for P2P ports.${NC}"
                
                # Ask about RPC/API ports
                read -p "Would you like to open the RPC (8545) and API (5052) ports to external access? This is typically NOT recommended for security. (y/N): " -r OPEN_API
                if [[ $OPEN_API =~ ^[Yy]$ ]]; then
                    sudo ufw allow 8545/tcp comment 'PulseChain RPC API'
                    sudo ufw allow 5052/tcp comment 'PulseChain Lighthouse API'
                    echo -e "${RED}Warning: API ports are now publicly accessible. Ensure you have proper security measures in place.${NC}"
                else
                    echo -e "${GREEN}Good choice. API ports remain closed to external access for security.${NC}"
                    echo -e "${YELLOW}You can still access them locally or set up a secure proxy later.${NC}"
                fi
            else
                echo -e "${YELLOW}Skipping automatic firewall configuration.${NC}"
                echo -e "${YELLOW}Please manually configure your firewall to allow ports $go_pulse_p2p and $lighthouse_p2p.${NC}"
            fi
        else
            echo -e "${YELLOW}UFW is installed but not active.${NC}"
            read -p "Would you like to enable UFW and configure it for PulseChain? (y/N): " -r ENABLE_UFW
            if [[ $ENABLE_UFW =~ ^[Yy]$ ]]; then
                # Set up default rules
                sudo ufw default deny incoming
                sudo ufw default allow outgoing
                
                # Allow SSH to prevent lockout
                sudo ufw allow ssh comment 'SSH access'
                
                # Allow PulseChain ports
                sudo ufw allow "$go_pulse_p2p"/tcp comment 'PulseChain go-pulse P2P'
                sudo ufw allow "$go_pulse_p2p"/udp comment 'PulseChain go-pulse P2P'
                sudo ufw allow "$lighthouse_p2p"/tcp comment 'PulseChain lighthouse P2P'
                sudo ufw allow "$lighthouse_p2p"/udp comment 'PulseChain lighthouse P2P'
                
                # Prompt for enabling
                echo -e "${RED}Warning: We are about to enable the firewall. This will apply the rules immediately.${NC}"
                echo -e "${RED}Ensure SSH (port 22) access is allowed to prevent being locked out.${NC}"
                read -p "Proceed with enabling UFW firewall? (y/N): " -r CONFIRM_UFW
                if [[ $CONFIRM_UFW =~ ^[Yy]$ ]]; then
                    sudo ufw --force enable
                    echo -e "${GREEN}UFW firewall enabled and configured.${NC}"
                else
                    echo -e "${YELLOW}UFW configuration prepared but not enabled.${NC}"
                    echo -e "${YELLOW}Run 'sudo ufw enable' manually when ready.${NC}"
                fi
            else
                echo -e "${YELLOW}Skipping firewall configuration.${NC}"
                echo -e "${YELLOW}Remember to configure your firewall manually to allow ports $go_pulse_p2p and $lighthouse_p2p.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}UFW not installed. Consider installing a firewall and allowing ports $go_pulse_p2p and $lighthouse_p2p.${NC}"
    fi
}

# Function to create secure JWT token
create_secure_jwt() {
    local jwt_file="$1"
    
    echo -e "${YELLOW}Creating secure JWT token...${NC}"
    
    # Generate random hex token
    if [ ! -f "$jwt_file" ]; then
        openssl rand -hex 32 | sudo tee "$jwt_file" > /dev/null
        echo -e "${GREEN}JWT token generated.${NC}"
    else
        echo -e "${GREEN}JWT token already exists. Keeping existing token.${NC}"
    fi
    
    # Set proper ownership and permissions
    sudo chown root:"$NODE_GROUP" "$jwt_file"
    sudo chmod 640 "$jwt_file"  # rw-r-----
    
    echo -e "${GREEN}JWT token secured.${NC}"
}

# Initialize permissions system
setup_node_permissions

# Check for GUI components (only if using GUI features)
if [ -z "$DISPLAY" ]; then
    echo -e "${YELLOW}No graphical environment detected.${NC}"
    echo -e "${YELLOW}GUI features like monitoring dashboard will not work.${NC}"
    read -p "Would you like to install a desktop environment? This will take significant time and disk space. (y/N): " -r INSTALL_DESKTOP
    if [[ $INSTALL_DESKTOP =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installing Ubuntu desktop environment. This may take a while...${NC}"
        if sudo apt install -y ubuntu-desktop; then
            echo -e "${GREEN}Desktop environment installed.${NC}"
            echo -e "${YELLOW}You may need to reboot after installation completes.${NC}"
        else
            echo -e "${RED}Failed to install desktop environment.${NC}"
            echo -e "${YELLOW}Continuing with installation, but GUI features will not work.${NC}"
        fi
    else
        echo -e "${YELLOW}Continuing without desktop environment. GUI features will not work.${NC}"
    fi
else
    echo -e "${GREEN}Graphical environment detected. GUI features will be available.${NC}"
    
    # Check for terminal emulators if we have a display
    TERMINAL_FOUND=false
    for terminal in gnome-terminal konsole xterm xfce4-terminal; do
        if command -v $terminal &> /dev/null; then
            TERMINAL_FOUND=true
            echo -e "${GREEN}Found terminal: $terminal${NC}"
            break
        fi
    done
    
    if [ "$TERMINAL_FOUND" = false ]; then
        echo -e "${YELLOW}No supported terminal emulator found for dashboard features.${NC}"
        read -p "Install gnome-terminal? (Y/n): " -r INSTALL_TERMINAL
        if [[ ! $INSTALL_TERMINAL =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installing gnome-terminal...${NC}"
            if sudo apt install -y gnome-terminal; then
                echo -e "${GREEN}gnome-terminal installed successfully.${NC}"
            else
                echo -e "${RED}Failed to install terminal emulator.${NC}"
                echo -e "${YELLOW}Dashboard features will not work properly.${NC}"
            fi
        fi
    fi
fi

# Function to check and install/update packages
check_install() {
    local pkg="$1"
    local min_version="$2"
    
    # Check if package is installed
    if ! command -v "$pkg" &> /dev/null; then
        echo -e "${YELLOW}$pkg not found. Installing...${NC}"
        sudo apt install -y "$pkg" || { echo -e "${RED}Failed to install $pkg${NC}"; exit 1; }
    else
        # If minimum version is specified, check version
        if [ -n "$min_version" ]; then
            local current_version
            # Get version in a more generic way that works for different Docker flavors
            if [ "$pkg" = "docker.io" ] || [ "$pkg" = "docker-ce" ] || [ "$pkg" = "docker" ]; then
                current_version=$(docker --version | awk '{print $3}' | tr -d ',')
            else
                current_version=$("$pkg" --version 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d ',v')
            fi
            
            if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" != "$min_version" ]; then
                echo -e "${YELLOW}$pkg is outdated (current: $current_version, required: >=$min_version).${NC}"
                read -p "Update $pkg? (Y/n): " -r
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    sudo apt install -y "$pkg" || echo -e "${YELLOW}Update failed, but continuing with existing version.${NC}"
                else
                    echo "Skipping update."
                fi
            else
                echo -e "${GREEN}$pkg is up to date.${NC}"
            fi
        fi
    fi
}

# Install required dependencies
install_dependencies() {
    echo -e "${GREEN}Installing dependencies...${NC}"
    
    # Update package list with better error handling
    echo "Updating package lists..."
    sudo apt update -y || { echo -e "${RED}Failed to update package lists. Continuing anyway...${NC}"; }
    
    # Install Docker
    check_install docker.io "20.10"
    sudo systemctl start docker || { echo -e "${RED}Failed to start Docker service${NC}"; exit 1; }
    sudo systemctl enable docker || { echo -e "${RED}Failed to enable Docker service${NC}"; exit 1; }
    
    # Install other necessary packages
    # jq is used for reliable JSON parsing in status check scripts
    sudo apt install -y bc openssl net-tools jq || { echo -e "${RED}Failed to install required packages${NC}"; exit 1; }
    
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
}

# Check system requirements
check_requirements() {
    echo -e "${GREEN}Checking system requirements...${NC}"
    
    # Check RAM (16GB recommended) - more precise calculation from MB
    RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    RAM_GB=$(echo "scale=1; $RAM_MB/1024" | bc)
    if (( $(echo "$RAM_GB < 16" | bc -l) )); then
        echo -e "${RED}Warning: Only $RAM_GB GB RAM detected (16GB+ recommended).${NC}"
        read -p "Continue anyway? (y/N): " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        echo -e "${GREEN}RAM check passed: $RAM_GB GB detected.${NC}"
    fi

    # Check CPU cores (4+ recommended)
    CPU_CORES=$(nproc --all)
    if [ "$CPU_CORES" -lt 4 ]; then
        echo -e "${RED}Warning: Only $CPU_CORES CPU cores detected (4+ recommended).${NC}"
        read -p "Continue anyway? (y/N): " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        echo -e "${GREEN}CPU check passed: $CPU_CORES cores detected.${NC}"
    fi
    
    echo -e "${GREEN}System requirements checked.${NC}"
}

# Validate numeric input
validate_numeric() {
    local value="$1"
    local default="$2"
    local name="$3"
    
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid input for $name. Using default value: $default${NC}"
        echo "$default"
    else
        echo "$value"
    fi
}

# Function to configure node parameters
configure_node_parameters() {
    echo -e "${GREEN}Configuring Archive Node Parameters...${NC}"
    
    # Default values
    MAX_PEERS=50
    MAX_PENDING_PEERS=100
    CACHE_SIZE=4096
    
    echo -e "${YELLOW}Node Parameters Configuration${NC}"
    echo "These parameters affect node performance and resource usage."
    echo "Press Enter to accept default values or enter new values."
    echo "For a complete list of all available options, see node-options.md"
    
    # Show current values and allow editing with validation
    read -p "Max peers (default: $MAX_PEERS): " -r USER_MAX_PEERS
    if [ -n "$USER_MAX_PEERS" ]; then
        MAX_PEERS=$(validate_numeric "$USER_MAX_PEERS" "$MAX_PEERS" "Max peers")
    fi
    
    read -p "Max pending peers (default: $MAX_PENDING_PEERS): " -r USER_MAX_PENDING_PEERS
    if [ -n "$USER_MAX_PENDING_PEERS" ]; then
        MAX_PENDING_PEERS=$(validate_numeric "$USER_MAX_PENDING_PEERS" "$MAX_PENDING_PEERS" "Max pending peers")
    fi
    
    read -p "Cache size in MB (default: $CACHE_SIZE): " -r USER_CACHE_SIZE
    if [ -n "$USER_CACHE_SIZE" ]; then
        CACHE_SIZE=$(validate_numeric "$USER_CACHE_SIZE" "$CACHE_SIZE" "Cache size")
    fi
    
    # Save parameters to config file for future use
    cat > "$DATA_DIR/node_config.env" << EOL
MAX_PEERS=$MAX_PEERS
MAX_PENDING_PEERS=$MAX_PENDING_PEERS
CACHE_SIZE=$CACHE_SIZE
EOL
    
    echo -e "${GREEN}Node parameters configured and saved to $DATA_DIR/node_config.env${NC}"
    
    # Copy the options documentation if it exists
    if [ -f "node-options.md" ]; then
        cp "node-options.md" "$DATA_DIR/"
        echo -e "${GREEN}Node options documentation copied to $DATA_DIR/node-options.md${NC}"
    else
        echo -e "${YELLOW}Note: node-options.md not found. You can download it from:${NC}"
        echo -e "${YELLOW}https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer/blob/main/node-options.md${NC}"
    fi
}

# Configure node
configure_node() {
    echo -e "${GREEN}Configuring node settings...${NC}"
    
    # Initialize variables with default values
    # These will be set based on user input and used throughout the installation
    NETWORK=""
    NETWORK_FLAG=""
    CHECKPOINT=""
    DATA_DIR=""
    CONFIG_DIR=""
    JWT_FILE=""
    
    # Prompt for network choice
    # PulseChain has two networks: mainnet (production) and testnet (for testing)
    echo "Which PulseChain network would you like to use?"
    read -p "Enter 'mainnet' or 'testnet' (default: mainnet): " -r NETWORK
    NETWORK=${NETWORK:-mainnet}
    if [ "$NETWORK" = "testnet" ]; then
        # Testnet requires different flags and checkpoint sync URL
        NETWORK_FLAG="--network pulsechain-testnet-v4"
        CHECKPOINT="--checkpoint-sync-url https://checkpoint.v4.testnet.pulsechain.com"
        echo -e "${GREEN}Selected network: Testnet${NC}"
    else
        # Mainnet is the default production network
        NETWORK_FLAG="--network pulsechain"
        CHECKPOINT=""
        echo -e "${GREEN}Selected network: Mainnet${NC}"
    fi

    # Prompt for data directory
    # This is where all blockchain data will be stored - needs significant disk space
    read -p "Enter data directory (default: $DEFAULT_DATA_DIR): " -r DATA_DIR
    DATA_DIR=${DATA_DIR:-$DEFAULT_DATA_DIR}
    echo -e "${GREEN}Data directory: $DATA_DIR${NC}"
    
    # Create directories and apply standardized permissions
    # This ensures all directories have the correct ownership and access rights
    apply_standard_permissions "$DATA_DIR" "data"
    apply_standard_permissions "$DATA_DIR/go-pulse" "data"
    apply_standard_permissions "$DATA_DIR/lighthouse" "data"
    
    # Apply permissions to config directory if not in the blockchain directory
    # Configuration files need appropriate permissions for security
    CONFIG_DIR="$DATA_DIR"
    apply_standard_permissions "$CONFIG_DIR" "config"

    # Check available storage (1TB recommended) with standardized units
    # Archive nodes require significant disk space to store the full blockchain history
    SPACE_GB=$(df -BG "$DATA_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if (( $(echo "$SPACE_GB < 1000" | bc -l) )); then
        echo -e "${RED}Warning: Only $SPACE_GB GB free at $DATA_DIR (1TB+ recommended).${NC}"
        read -p "Continue anyway? (y/N): " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    else
        echo -e "${GREEN}Storage check passed: $SPACE_GB GB available.${NC}"
    fi

    # Generate JWT secret using our secure function
    JWT_FILE="$DATA_DIR/jwt.hex"
    create_secure_jwt "$JWT_FILE"
    
    # Configure node parameters
    configure_node_parameters
    
    echo -e "${GREEN}Node configuration completed.${NC}"
}

# Function to check and resolve port conflicts with validation
check_port() {
    local port="$1"
    local name="$2"
    local new_port=""
    
    if sudo netstat -tuln | grep -q ":$port "; then
        echo -e "${RED}Port $port ($name) is already in use.${NC}"
        while true; do
            read -p "Enter a new port for $name (1024-65535): " -r new_port
            # Validate port number
            if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
                echo -e "${RED}Invalid port number. Port must be between 1024 and 65535.${NC}"
                continue
            fi
            
            # Check if the new port is also in use
            if sudo netstat -tuln | grep -q ":$new_port "; then
                echo -e "${RED}Port $new_port is also in use. Please choose another port.${NC}"
                continue
            fi
            
            break
        done
        echo -e "${YELLOW}Changing $name port from $port to $new_port due to conflict${NC}"
        echo "$new_port"
    else
        echo "$port"
    fi
}

# Deploy Docker containers
deploy_containers() {
    echo -e "${GREEN}Deploying Docker containers...${NC}"
    
    # Initialize variables with default values
    GO_PULSE_PORT=""
    GO_PULSE_P2P=""
    LIGHTHOUSE_PORT=""
    LIGHTHOUSE_P2P=""
    MAX_PEERS=50
    MAX_PENDING_PEERS=100
    CACHE_SIZE=4096
    CONTINUE_LIGHTHOUSE=""
    
    # Create Docker network
    docker_cmd network create pulsechain-net 2>/dev/null || echo "Docker network 'pulsechain-net' already exists."

    # Remove old containers if they exist
    for container in go-pulse lighthouse; do
        if [ "$(docker_cmd ps -aq -f name=$container)" ]; then
            echo -e "${YELLOW}Found existing $container container.${NC}"
            read -p "Remove it? (Y/n): " -r
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then 
                docker_cmd rm -f "$container"
            else
                echo -e "${RED}Aborting due to existing container.${NC}"
                exit 1
            fi
        fi
    done

    # Assign and check ports
    echo "Checking port availability..."
    GO_PULSE_PORT=$(check_port 8545 "go-pulse HTTP")
    GO_PULSE_P2P=$(check_port 30303 "go-pulse P2P")
    LIGHTHOUSE_PORT=$(check_port 5052 "lighthouse HTTP")
    LIGHTHOUSE_P2P=$(check_port 9000 "lighthouse P2P")

    echo -e "${GREEN}Pulling Docker images...${NC}"
    # Pull Docker images with retry logic
    for image in "registry.gitlab.com/pulsechaincom/go-pulse:latest" "registry.gitlab.com/pulsechaincom/lighthouse-pulse:latest"; do
        for attempt in {1..3}; do
            echo "Pulling $image (attempt $attempt/3)..."
            if docker_cmd pull "$image"; then
                echo -e "${GREEN}Successfully pulled $image${NC}"
                break
            fi
            
            if [ "$attempt" -eq 3 ]; then
                echo -e "${RED}Failed to pull $image after 3 attempts.${NC}"
                echo "Check your internet connection and try again later."
                read -p "Continue anyway? (y/N): " -r
                [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
            else
                echo -e "${YELLOW}Pull failed, retrying in 5 seconds...${NC}"
                sleep 5
            fi
        done
    done

    # Load custom parameters if they exist
    if [ -f "$DATA_DIR/node_config.env" ]; then
        # shellcheck source=/dev/null
        source "$DATA_DIR/node_config.env"
        echo -e "${GREEN}Loaded custom node parameters.${NC}"
    else
        # Default values if no config file exists
        MAX_PEERS=50
        MAX_PENDING_PEERS=100
        CACHE_SIZE=4096
    fi

    echo -e "${GREEN}Starting go-pulse container...${NC}"
    # Run go-pulse container with enhanced security options
    if ! docker_cmd run -d \
        --name go-pulse \
        --network pulsechain-net \
        --restart unless-stopped \
        --security-opt=no-new-privileges \
        --cap-drop=ALL \
        --cap-add=NET_BIND_SERVICE \
        -v "$DATA_DIR/go-pulse:/blockchain" \
        -v "$JWT_FILE:/blockchain/jwt.hex:ro" \
        -p "$GO_PULSE_PORT:8545" \
        -p "$GO_PULSE_P2P:30303" \
        registry.gitlab.com/pulsechaincom/go-pulse:latest \
        --datadir=/blockchain \
        --syncmode=archive \
        --http \
        --http.addr=0.0.0.0 \
        --authrpc.jwtsecret=/blockchain/jwt.hex \
        --maxpeers="$MAX_PEERS" \
        --maxpendpeers="$MAX_PENDING_PEERS" \
        --cache="$CACHE_SIZE" \
        "$( [ "$NETWORK" = "mainnet" ] && echo "" || echo "$NETWORK_FLAG" )"; then
        echo -e "${RED}Error: Failed to start go-pulse container.${NC}"
        echo -e "${YELLOW}Check the Docker logs for more details: docker logs go-pulse${NC}"
        read -p "Continue with lighthouse deployment anyway? (y/N): " -r CONTINUE_LIGHTHOUSE
        if [[ ! $CONTINUE_LIGHTHOUSE =~ ^[Yy]$ ]]; then
            echo -e "${RED}Deployment aborted.${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}Starting lighthouse container...${NC}"
    # Run lighthouse container with enhanced security options
    if ! docker_cmd run -d \
        --name lighthouse \
        --network pulsechain-net \
        --restart unless-stopped \
        --security-opt=no-new-privileges \
        --cap-drop=ALL \
        --cap-add=NET_BIND_SERVICE \
        -v "$DATA_DIR/lighthouse:/data" \
        -v "$JWT_FILE:/data/jwt.hex:ro" \
        -p "$LIGHTHOUSE_PORT:5052" \
        -p "$LIGHTHOUSE_P2P:9000" \
        registry.gitlab.com/pulsechaincom/lighthouse-pulse:latest \
        lighthouse beacon_node \
        --datadir /data \
        --execution-endpoint "http://go-pulse:8545" \
        --execution-jwt /data/jwt.hex \
        --http \
        --http-address 0.0.0.0 \
        "$NETWORK_FLAG" \
        "$CHECKPOINT"; then
        echo -e "${RED}Error: Failed to start lighthouse container.${NC}"
        echo -e "${YELLOW}Check the Docker logs for more details: docker logs lighthouse${NC}"
        echo -e "${RED}Deployment partially completed. go-pulse may be running but lighthouse failed.${NC}"
    else
        echo -e "${GREEN}Containers deployed.${NC}"
        echo -e "${YELLOW}Note: You can use ./shutdown.sh for graceful shutdown and ./restart.sh to restart.${NC}"
    fi
    
    # Set up firewall rules for the P2P ports
    setup_firewall "$GO_PULSE_P2P" "$LIGHTHOUSE_P2P"
}

# Verify installation
verify_installation() {
    echo -e "${GREEN}Verifying installation...${NC}"
    
    # Check if containers are running
    if [ "$(docker_cmd ps -q -f name=go-pulse)" ] && [ "$(docker_cmd ps -q -f name=lighthouse)" ]; then
        echo -e "${GREEN}Success! PulseChain Archive Node is running.${NC}"
        
        # Output container IDs and status
        echo -e "\nContainer status:"
        docker_cmd ps -a | grep -E 'go-pulse|lighthouse'
        
        # Print connection information
        echo -e "\n${GREEN}Connection Information:${NC}"
        echo "Go-pulse RPC endpoint: http://localhost:$GO_PULSE_PORT"
        echo "Lighthouse API endpoint: http://localhost:$LIGHTHOUSE_PORT"
        
        # Print monitoring commands
        echo -e "\n${GREEN}Monitoring Commands:${NC}"
        if [ "$DOCKER_USE_SUDO" = true ]; then
            echo "View go-pulse logs: sudo docker logs -f go-pulse"
            echo "View lighthouse logs: sudo docker logs -f lighthouse"
        else
            echo "View go-pulse logs: docker logs -f go-pulse"
            echo "View lighthouse logs: docker logs -f lighthouse"
        fi
        
        # Firewall status is now handled by the setup_firewall function
        
        # Print sync time warning
        echo -e "\n${YELLOW}Note:${NC} Syncing may take days or weeks on mainnet; testnet is faster with checkpoint sync."
    else
        echo -e "${RED}Error: One or both containers failed to start.${NC}"
        if [ "$DOCKER_USE_SUDO" = true ]; then
            echo "Check logs with 'sudo docker logs go-pulse' or 'sudo docker logs lighthouse' for details."
        else
            echo "Check logs with 'docker logs go-pulse' or 'docker logs lighthouse' for details."
        fi
        exit 1
    fi
}

# Create desktop shortcuts for easy access
create_desktop_shortcuts() {
    echo -e "${GREEN}Creating desktop shortcuts...${NC}"
    
    # Get the current installation directory (where the scripts are located)
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Get the user's desktop directory
    DESKTOP_DIR="$HOME/Desktop"
    
    # Create the desktop directory if it doesn't exist (rare case)
    mkdir -p "$DESKTOP_DIR"
    
    # Validate the environment for desktop shortcuts
    if ! validate_desktop_environment; then
        echo -e "${YELLOW}Desktop environment validation failed. Skipping desktop shortcut creation.${NC}"
        echo -e "${YELLOW}You can still use all scripts from the command line.${NC}"
        return 1
    fi
    
    # Function to create a desktop shortcut
    create_shortcut() {
        local name="$1"
        local script="$2"
        local icon="$3"
        local comment="$4"
        
        # Check if the script exists before creating shortcut
        if [ ! -f "$INSTALL_DIR/$script" ]; then
            echo -e "${YELLOW}Warning: $script not found, skipping shortcut${NC}"
            return 1
        fi
        
        # Create the .desktop file
        cat > "$DESKTOP_DIR/$name.desktop" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$TERMINAL_CMD bash -c "cd $INSTALL_DIR && ./$script; exec bash"
Icon=$icon
Terminal=true
StartupNotify=true
Categories=Utility;
EOL
        
        # Make it executable with safe permissions
        chmod 644 "$DESKTOP_DIR/$name.desktop"
        
        echo -e "${GREEN}Created '$name' desktop shortcut${NC}"
    }
    
    # Create shortcuts for each operation
    create_shortcut "PulseChain - Graceful Shutdown" "shutdown.sh" "system-shutdown" "Gracefully shut down the PulseChain node"
    create_shortcut "PulseChain - Restart Node" "restart.sh" "system-reboot" "Start or restart the PulseChain node"
    create_shortcut "PulseChain - Edit Parameters" "edit-parameters.sh" "preferences-system" "Edit PulseChain node parameters"
    create_shortcut "PulseChain - Check Status" "monitor-node.sh" "utilities-system-monitor" "Check PulseChain node status"
    create_shortcut "PulseChain - Monitoring Dashboard" "monitor-dashboard.sh" "utilities-terminal" "Open monitoring dashboard with multiple windows"
    
    # Apply standard permissions to the scripts directory
    apply_standard_permissions "$INSTALL_DIR" "scripts"
    
    echo -e "${GREEN}Desktop shortcuts created successfully!${NC}"
    echo -e "${YELLOW}Note: You may need to log out and back in for the icons to appear correctly.${NC}"
}

# Validate the desktop environment
validate_desktop_environment() {
    # Initialize variables
    local create_anyway=""
    TERMINAL_CMD=""
    
    # Check if we are in a desktop environment
    if [ -z "$XDG_CURRENT_DESKTOP" ] && [ -z "$GNOME_DESKTOP_SESSION_ID" ] && [ -z "$KDE_FULL_SESSION" ]; then
        echo -e "${YELLOW}Warning: No desktop environment detected.${NC}"
        
        # Ask user if they want to continue with shortcut creation
        read -p "Create desktop shortcuts anyway? (y/N): " -r create_anyway
        if [[ ! "$create_anyway" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Check if gnome-terminal is available (used in shortcuts)
    if ! command -v gnome-terminal &> /dev/null; then
        if command -v xterm &> /dev/null; then
            echo -e "${YELLOW}gnome-terminal not found, but xterm is available. Using xterm instead.${NC}"
            # Modify the create_shortcut function to use xterm
            TERMINAL_CMD="xterm -e"
        elif command -v konsole &> /dev/null; then
            echo -e "${YELLOW}gnome-terminal not found, but konsole is available. Using konsole instead.${NC}"
            TERMINAL_CMD="konsole -e"
        else
            echo -e "${RED}No suitable terminal emulator found.${NC}"
            return 1
        fi
    else
        TERMINAL_CMD="gnome-terminal --"
    fi
    
    # Check if we can write to the desktop directory
    if ! touch "$HOME/Desktop/.test_write_permission" 2>/dev/null; then
        echo -e "${RED}Cannot write to Desktop directory.${NC}"
        return 1
    else
        rm "$HOME/Desktop/.test_write_permission"
    fi
    
    return 0
}

# Setup auto-recovery cron job
setup_auto_recovery() {
    echo -e "${GREEN}Setting up auto-recovery...${NC}"
    
    # Initialize variables
    local ENABLE_AUTO_RECOVERY=""
    local LOGS_DIR=""
    local AUTO_RECOVERY_SCRIPT=""
    local CRON_JOB=""
    
    # Get the current installation directory
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Ask user if they want to enable auto-recovery
    read -p "Would you like to enable automatic recovery of the node in case of issues? (y/N): " -r ENABLE_AUTO_RECOVERY
    
    if [[ "$ENABLE_AUTO_RECOVERY" =~ ^[Yy]$ ]]; then
        # Create log directory with proper permissions
        LOGS_DIR="$INSTALL_DIR/logs"
        apply_standard_permissions "$LOGS_DIR" "logs"
        
        # Create the auto-recovery script with sudo paths if needed
        AUTO_RECOVERY_SCRIPT="$INSTALL_DIR/auto-recovery.sh"
        if [ -f "$AUTO_RECOVERY_SCRIPT" ]; then
            # Update docker commands in auto-recovery script to use sudo if needed
            if [ "$DOCKER_USE_SUDO" = true ]; then
                sed -i 's/docker /sudo docker /g' "$AUTO_RECOVERY_SCRIPT"
                echo -e "${GREEN}Updated auto-recovery script to use sudo for docker commands.${NC}"
            else
                sed -i 's/sudo docker /docker /g' "$AUTO_RECOVERY_SCRIPT"
                echo -e "${GREEN}Updated auto-recovery script to use docker without sudo.${NC}"
            fi
        else
            echo -e "${RED}Warning: auto-recovery.sh not found in $INSTALL_DIR${NC}"
            echo -e "${YELLOW}Auto-recovery will not work until this script is created.${NC}"
        fi
        
        # Ensure the auto-recovery script has proper permissions
        if [ -f "$AUTO_RECOVERY_SCRIPT" ]; then
            sudo chmod 755 "$AUTO_RECOVERY_SCRIPT"
            sudo chown "$NODE_USER":"$NODE_GROUP" "$AUTO_RECOVERY_SCRIPT"
            echo -e "${GREEN}Set secure permissions on auto-recovery script.${NC}"
        fi
        
        # Create the cron job (runs every 10 minutes)
        CRON_JOB="*/10 * * * * $INSTALL_DIR/auto-recovery.sh >> $LOGS_DIR/recovery.log 2>&1"
        
        # Idempotent cron job setup - only add if not already there
        if ! crontab -l 2>/dev/null | grep -q "$INSTALL_DIR/auto-recovery.sh"; then
            (crontab -l 2>/dev/null || echo "") | grep -v "$INSTALL_DIR/auto-recovery.sh" | { cat; echo "$CRON_JOB"; } | crontab -
            echo -e "${GREEN}Auto-recovery has been enabled. The node will automatically recover from common issues.${NC}"
        else
            echo -e "${GREEN}Auto-recovery was already enabled.${NC}"
        fi
        
        echo -e "${GREEN}Recovery logs will be stored in: $LOGS_DIR/recovery.log${NC}"
    else
        echo -e "${YELLOW}Auto-recovery not enabled. You can manually run auto-recovery.sh when needed.${NC}"
    fi
}

# Main execution
main() {
    # Initialize key global variables
    DATA_DIR=""
    NETWORK=""
    NETWORK_FLAG=""
    CHECKPOINT=""
    JWT_FILE=""
    CONFIG_FILE=""
    INSTALL_DIR=""
    
    check_requirements
    install_dependencies
    configure_node
    deploy_containers
    verify_installation
    
    # Scripts directory setup for consistent permissions
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    apply_standard_permissions "$INSTALL_DIR" "scripts"
    
    # Set up auto-recovery
    setup_auto_recovery
    
    # Create desktop shortcuts
    create_desktop_shortcuts
    
    # Create a configuration file that stores the docker usage method for other scripts
    CONFIG_FILE="$INSTALL_DIR/node_env.sh"
    cat > "$CONFIG_FILE" << EOL
#!/bin/bash
# Generated configuration for PulseChain Archive Node
# This file is sourced by other scripts to maintain consistent settings

NODE_USER="$NODE_USER"
NODE_GROUP="$NODE_GROUP"
DATA_DIR="$DATA_DIR"
DOCKER_USE_SUDO=$DOCKER_USE_SUDO

# Function to standardize docker command with or without sudo
docker_cmd() {
    if [ "\$DOCKER_USE_SUDO" = true ]; then
        sudo docker "\$@"
    else
        docker "\$@"
    fi
}
EOL
    chmod 755 "$CONFIG_FILE"
    
    echo -e "${GREEN}PulseChain Archive Node installation completed!${NC}"
    echo -e "${GREEN}A configuration file has been created at $CONFIG_FILE that other scripts will use.${NC}"
    
    # Final instructions
    echo -e "\n${YELLOW}Important Next Steps:${NC}"
    echo -e "1. You may need to log out and back in for group permissions to take full effect"
    echo -e "2. Monitor your node with ./monitor-node.sh"
    echo -e "3. When shutting down your node, always use ./shutdown.sh for a clean shutdown"
    
    # Check if node is running and remind about syncing
    if [ "$(docker_cmd ps -q -f name=go-pulse)" ] && [ "$(docker_cmd ps -q -f name=lighthouse)" ]; then
        echo -e "\n${GREEN}Your node is running! Initial synchronization is in progress.${NC}"
        echo -e "${YELLOW}Note: Full synchronization may take days or weeks depending on your hardware and network.${NC}"
    fi
}

# Run the main function
main 