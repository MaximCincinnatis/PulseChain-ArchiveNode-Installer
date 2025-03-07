#!/bin/bash

# PulseChain Archive Node - Dashboard Launcher
# This script opens multiple terminal windows with different monitoring information

# Color definitions for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    PulseChain Archive Node - Dashboard Launcher   ${NC}"
echo -e "${BLUE}=================================================${NC}"

# Get current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if required scripts exist
if [ ! -x "$CURRENT_DIR/monitor-node.sh" ]; then
    echo -e "${RED}Error: monitor-node.sh not found or not executable in $CURRENT_DIR${NC}"
    echo "Please ensure the script exists and has execute permissions (chmod +x monitor-node.sh)"
    exit 1
fi

# Check if Docker is installed (required for container logs)
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not found. Cannot display container logs.${NC}"
    echo "Please install Docker to use this dashboard."
    exit 1
fi

# Check if we're in a graphical environment
if [ -z "$DISPLAY" ]; then
    echo -e "${RED}Error: No display detected. This script requires a graphical environment.${NC}"
    echo "You can still monitor your node with these commands:"
    echo "  - Node status: ./monitor-node.sh"
    echo "  - Go-pulse logs: docker logs -f go-pulse"
    echo "  - Lighthouse logs: docker logs -f lighthouse"
    echo "  - System resources: htop"
    exit 1
fi

# Function to detect available terminal emulators
detect_terminal() {
    if command -v gnome-terminal &> /dev/null; then
        echo "gnome-terminal"
    elif command -v konsole &> /dev/null; then
        echo "konsole"
    elif command -v xterm &> /dev/null; then
        echo "xterm"
    elif command -v xfce4-terminal &> /dev/null; then
        echo "xfce4-terminal"
    else
        echo ""
    fi
}

# Get terminal emulator
TERMINAL=$(detect_terminal)

if [ -z "$TERMINAL" ]; then
    echo -e "${RED}Error: No supported terminal emulator found.${NC}"
    echo "Please install gnome-terminal, konsole, xterm, or xfce4-terminal."
    exit 1
fi

echo -e "${GREEN}Using terminal: $TERMINAL${NC}"

# Detect screen size and calculate positions
# Default positions for 1600x900 or larger screens
POS1="80x20+0+0"
POS2="80x20+800+0"
POS3="80x20+0+400"
POS4="80x20+800+400"

# Try to detect screen size if xrandr is available
if command -v xrandr &> /dev/null; then
    SCREEN_WIDTH=$(xrandr | grep -oP 'current \K\d+(?= x)')
    SCREEN_HEIGHT=$(xrandr | grep -oP 'current \d+ x \K\d+(?=,)')
    
    # Only adjust if we got valid numbers
    if [[ "$SCREEN_WIDTH" =~ ^[0-9]+$ ]] && [[ "$SCREEN_HEIGHT" =~ ^[0-9]+$ ]]; then
        HALF_WIDTH=$((SCREEN_WIDTH / 2))
        HALF_HEIGHT=$((SCREEN_HEIGHT / 2))
        
        # Adjust positions based on screen dimensions
        POS1="80x20+0+0"
        POS2="80x20+$HALF_WIDTH+0"
        POS3="80x20+0+$HALF_HEIGHT"
        POS4="80x20+$HALF_WIDTH+$HALF_HEIGHT"
        
        echo -e "${GREEN}Detected screen size: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}, adjusting window positions${NC}"
    else
        echo -e "${YELLOW}Could not parse screen dimensions, using default positions${NC}"
    fi
else
    echo -e "${YELLOW}xrandr not found, using default window positions${NC}"
fi

# Display information and warnings
echo -e "${YELLOW}This will open 4 terminal windows for monitoring:${NC}"
echo "  1. Node Status (top left)"
echo "  2. System Resources (top right)"
echo "  3. Go-Pulse Logs (bottom left)"
echo "  4. Lighthouse Logs (bottom right)"
echo
echo -e "${YELLOW}Note: This dashboard may use significant CPU/memory on low-spec systems.${NC}"

# Ask for confirmation
read -p "Launch dashboard? (Y/n): " -r confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Dashboard launch cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Launching dashboard windows...${NC}"

# Function to launch a terminal window with a specific command
launch_terminal() {
    local title=$1
    local command=$2
    local position=$3  # Format: "WIDTHxHEIGHT+X+Y"
    local keep_open=$4 # Whether to keep terminal open with exec bash
    
    local exec_cmd=""
    if [ "$keep_open" = true ]; then
        exec_cmd="; exec bash"
    fi
    
    case $TERMINAL in
        "gnome-terminal")
            gnome-terminal --title="$title" --geometry="$position" -- bash -c "$command$exec_cmd"
            ;;
        "konsole")
            konsole --title="$title" --geometry="$position" -e bash -c "$command$exec_cmd"
            ;;
        "xterm")
            xterm -title "$title" -geometry "$position" -e bash -c "$command$exec_cmd" &
            ;;
        "xfce4-terminal")
            xfce4-terminal --title="$title" --geometry="$position" -e "bash -c \"$command$exec_cmd\""
            ;;
    esac
    
    # Delay to avoid overwhelming the system
    sleep 1
}

# Check if the system has htop installed
if ! command -v htop &> /dev/null; then
    echo -e "${YELLOW}htop not found. Using top for system monitoring instead.${NC}"
    SYS_MONITOR_CMD="top"
else
    SYS_MONITOR_CMD="htop"
fi

# Launch the windows
# 1. Node Status (Top Left) - Keep open if command ends
launch_terminal "PulseChain Node Status" "cd \"$CURRENT_DIR\" && watch -n 5 ./monitor-node.sh" "$POS1" true

# 2. System Resources (Top Right)
launch_terminal "System Resources" "$SYS_MONITOR_CMD" "$POS2" true

# 3. Go-Pulse Logs (Bottom Left) - Continuous logs don't need exec bash
launch_terminal "Go-Pulse Logs" "docker logs -f go-pulse" "$POS3" false

# 4. Lighthouse Logs (Bottom Right) - Continuous logs don't need exec bash
launch_terminal "Lighthouse Logs" "docker logs -f lighthouse" "$POS4" false

echo -e "${GREEN}Dashboard launched!${NC}"
echo -e "${YELLOW}Note: Closing this terminal will not close the dashboard windows.${NC}" 