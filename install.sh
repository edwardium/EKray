#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 0.9.1 (Reality Config Hotfix)
# Author: Kaveh & Edward
# GitHub: https://github.com/edwardium/EKray.git
# =================================================================

# --- Colors for output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Path to the sing-box configuration file
CONFIG_PATH="/etc/sing-box/config.json"

# --- Function to check for dependencies ---
check_dependencies() {
    DEPS="curl jq qrencode"
    for dep in $DEPS; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}Dependency '$dep' not found. Installing...${NC}"
            sudo apt-get update && sudo apt-get install -y "$dep"
        fi
    done
}

# --- Main Menu Display Function ---
show_main_menu() {
    clear
    echo "============================================="
    echo "         EKray Management Panel v0.9.1       "
    echo "             by Edward & Kaveh             "
    echo "============================================="
    echo "Please choose an option:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Update Server & Dependencies"
    echo -e "  ${GREEN}2)${NC} Install/Update sing-box Core"
    echo -e "  ${GREEN}3)${NC} Service Management"
    echo -e "  ${RED}4)${NC} Exit"
    echo ""
    echo "---------------------------------------------"
}

# --- Service Management Sub-menu ---
service_management_menu() {
    clear
    echo "============================================="
    echo "             Service Management              "
    echo "============================================="
    echo "  1) Install Reality Service"
    echo "  2) Add Reality User"
    echo "  3) View Service Status"
    echo "  4) Uninstall Service (Clean Install)"
    echo "  5) Back to Main Menu"
    echo "---------------------------------------------"
    read -p "Enter your choice [1-5]: " service_choice

    case $service_choice in
        1) install_reality_service ;;
        2) add_reality_user ;;
        3) check_service_status ;;
        4) uninstall_service ;;
        5) return ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 2; service_management_menu ;;
    esac
    
    # After an action, prompt to return
    if [[ "$service_choice" -ne 5 ]]; then
        read -n 1 -s -r -p "Press any key to return to the service menu..."
    fi
    service_management_menu
}

# --- Function to uninstall and clean everything ---
uninstall_service() {
    echo -e "${RED}WARNING: This will stop the sing-box service and delete all configuration files.${NC}"
    read -p "Are you sure you want to continue? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        sudo systemctl stop sing-box
        sudo rm -f "$CONFIG_PATH"
        echo -e "${GREEN}Service uninstalled and configuration file removed.${NC}"
    else
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
    fi
}

# --- Function to install the first Reality service ---
install_reality_service() {
    if [ -f "$CONFIG_PATH" ]; then
        echo -e "${RED}A configuration file already exists. Please uninstall first using the menu.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Installing VLESS+Reality Service...${NC}"
    read -p "Enter the listen port (e.g., 443): " listen_port
    read -p "Enter the SNI domain (e.g., www.microsoft.com): " server_name

    # Generate Reality keys
    echo "Generating Reality key pair..."
    REALITY_KEYS=$(/usr/local/bin/sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}' | tr -d '",')
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}' | tr -d '",')

    # Create initial user
    first_user_uuid=$(/usr/local/bin/sing-box generate uuid)
    first_user_name="initial-user"

    # Create config.json
    sudo bash -c "cat > $CONFIG_PATH" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality-in",
      "listen": "::",
      "listen_port": ${listen_port},
      "users": [
        {
          "uuid": "${first_user_uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "transport": {
        "type": "tcp"
      },
      "tls": {
        "enabled": true,
        "server_name": "${server_name}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${server_name}",
            "server_port": 443
          },
          "private_key": "${PRIVATE_KEY}",
          "short_id": ""
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "secret": ""
    }
  }
}
EOF

    # Store public key separately for link generation (this is a simple method for now)
    echo "$PUBLIC_KEY" | sudo tee /etc/sing-box/reality.pub > /dev/null

    sudo systemctl restart sing-box
    sleep 2 # Wait for service to restart
    check_service_status

    echo -e "${GREEN}Reality service installed and started successfully!${NC}"
    echo "Generating connection info for the first user..."
    generate_reality_link "$first_user_name" "$first_user_uuid"
}

# --- Function to add a new Reality user ---
add_reality_user() {
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "${RED}Configuration file not found. Please install a service first.${NC}"
        return
    fi

    read -p "Enter a name for the new user (for identification): " user_name
    new_uuid=$(/usr/local/bin/sing-box generate uuid)

    # Add user to config using jq
    tmp_json=$(mktemp)
    jq --arg uuid "$new_uuid" '.inbounds[0].users += [{"uuid": $uuid, "flow": "xtls-rprx-vision"}]' "$CONFIG_PATH" > "$tmp_json"
    sudo mv "$tmp_json" "$CONFIG_PATH"


    sudo systemctl restart sing-box
    sleep 2
    echo -e "${GREEN}User '$user_name' with UUID '$new_uuid' added successfully.${NC}"

    generate_reality_link "$user_name" "$new_uuid"
}

# --- Function to generate and display Reality link ---
generate_reality_link() {
    local user_name=$1
    local uuid=$2

    # Extract info from config
    local server_ip=$(curl -s ip.me)
    local port=$(jq '.inbounds[0].listen_port' $CONFIG_PATH)
    local sni=$(jq -r '.inbounds[0].tls.server_name' $CONFIG_PATH)
    # Read public key from the file we saved
    local pbk=$(sudo cat /etc/sing-box/reality.pub)
    local sid=$(jq -r '.inbounds[0].tls.reality.short_id' $CONFIG_PATH)

    VLESS_LINK="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#EKray-${user_name}"

    echo ""
    echo -e "${YELLOW}Connection Link:${NC}"
    echo "$VLESS_LINK"
    echo ""
    echo -e "${YELLOW}QR Code:${NC}"
    qrencode -t ANSIUTF8 "$VLESS_LINK"
}

# --- Function to check service status ---
check_service_status() {
    sudo systemctl status sing-box --no-pager -l
}

# --- Main application loop ---
check_dependencies
while true; do
    show_main_menu
    read -p "Enter your choice [1-4]: " choice

    # Case statement for main menu
    case $choice in
        1) update_server ;;
        2) # install_singbox # You can add update logic here later
           echo "Install/Update functionality will be refined."
           sleep 2
           ;;
        3) service_management_menu ;;
        4) echo "Exiting the panel..."; exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 2 ;;
    esac
done

