#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 0.6 (International & Robust)
# Author: Kaveh & Edward
# GitHub: https://github.com/edwardium/EKray.git
# =================================================================

# --- Colors for output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Function to check for dependencies ---
check_dependencies() {
    DEPS="curl jq"
    for dep in $DEPS; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}Dependency '$dep' not found. Installing...${NC}"
            sudo apt-get update && sudo apt-get install -y "$dep"
        fi
    done
}

# --- Function to update the server ---
update_server() {
    echo -e "${YELLOW}Starting server update...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    echo -e "${GREEN}Server updated successfully!${NC}"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
}

# --- Function to install sing-box core ---
install_singbox() {
    if command -v sing-box &> /dev/null; then
        echo -e "${GREEN}sing-box is already installed.${NC}"
        read -n 1 -s -r -p "Press any key to return to the main menu..."
        return
    fi

    echo -e "${YELLOW}Installing the latest version of sing-box core...${NC}"

    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            return 1
            ;;
    esac

    # Get the latest version from GitHub API
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}Error getting the latest sing-box version. Please check your internet connection.${NC}"
        return 1
    fi
    
    echo "Latest version found: $LATEST_VERSION"
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/$LATEST_VERSION/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"

    # Download the file
    echo "Downloading from: $DOWNLOAD_URL"
    curl -sLo sing-box.tar.gz "$DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed.${NC}"
        return 1
    fi

    # Extract and install
    EXTRACT_DIR="sing-box-${LATEST_VERSION#v}-linux-${ARCH}"
    tar -xzf sing-box.tar.gz
    sudo install -m 755 "${EXTRACT_DIR}/sing-box" /usr/local/bin/
    sudo mkdir -p /etc/sing-box/
    
    # Cleanup
    rm -rf "${EXTRACT_DIR}" sing-box.tar.gz
    
    # Create service file
    create_service_file
    
    echo -e "${GREEN}sing-box core installed successfully.${NC}"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
}

# --- Function to create the systemd service file ---
create_service_file() {
    echo -e "${YELLOW}Creating systemd service file...${NC}"
    SERVICE_FILE_CONTENT="[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/etc/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target"

    echo "$SERVICE_FILE_CONTENT" | sudo tee /etc/systemd/system/sing-box.service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable sing-box
    echo -e "${GREEN}Service file created and sing-box service enabled.${NC}"
}


# --- Function to display the main menu ---
show_main_menu() {
    clear
    echo "============================================="
    echo "          EKray Management Panel v0.6        "
    echo "============================================="
    echo "Please choose an option:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Update Server & Dependencies"
    echo -e "  ${GREEN}2)${NC} Install sing-box Core"
    echo -e "  ${YELLOW}3)${NC} Service Management (Coming Soon)"
    echo -e "  ${RED}4)${NC} Exit"
    echo ""
    echo "---------------------------------------------"
}

# --- Main application loop ---
check_dependencies
while true; do
    show_main_menu
    read -p "Enter your choice [1-4]: " choice

    case $choice in
        1)
            update_server
            ;;
        2)
            install_singbox
            ;;
        3)
            echo -e "${YELLOW}This feature will be added in future versions.${NC}"
            sleep 2
            ;;
        4)
            echo "Exiting the panel..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 2
            ;;
    esac
done