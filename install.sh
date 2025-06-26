#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 0.9.3 (System Status Check)
# Author: Kaveh & Edward
# GitHub: https://github.com/edwardium/EKray.git
# =================================================================

# --- Colors for output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Paths ---
CONFIG_PATH="/etc/sing-box/config.json"
USER_DB_PATH="/etc/sing-box/users.db"
SINGBOX_BIN_PATH="/usr/local/bin/sing-box"
SERVICE_PATH="/etc/systemd/system/sing-box.service"

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
    echo "         EKray Management Panel v0.9.3       "
    echo "             by Edward & Kaveh             "
    echo "============================================="
    echo "Please choose an option:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Update Server & Dependencies"
    echo -e "  ${GREEN}2)${NC} Install/Update sing-box Core"
    echo -e "  ${GREEN}3)${NC} Service Management"
    echo -e "  ${GREEN}4)${NC} System Status Check"
    echo -e "  ${RED}5)${NC} Uninstall EKray & Core"
    echo -e "  ${RED}6)${NC} Exit"
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
    echo "  3) List Reality Users"
    echo "  4) View Service Status"
    echo "  5) Back to Main Menu"
    echo "---------------------------------------------"
    read -p "Enter your choice [1-5]: " service_choice

    case $service_choice in
        1) install_reality_service ;;
        2) add_reality_user ;;
        3) list_reality_users ;;
        4) check_service_status ;;
        5) return ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 2; service_management_menu ;;
    esac

    if [[ "$service_choice" -ne 5 ]]; then
        read -n 1 -s -r -p "Press any key to return to the service menu..."
    fi
    service_management_menu
}

# --- Function for System Status Check ---
system_status_check() {
    echo -e "${YELLOW}--- EKray System Status Check ---${NC}"

    # 1. Check for sing-box binary
    echo -n "1. Checking for sing-box core: "
    if [ -f "$SINGBOX_BIN_PATH" ]; then
        echo -e "${GREEN}Installed ($($SINGBOX_BIN_PATH version | awk '{print $3}'))${NC}"
    else
        echo -e "${RED}Not Found${NC}"
    fi

    # 2. Check for config directory
    echo -n "2. Checking for config directory: "
    if [ -d "/etc/sing-box" ]; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${RED}Not Found${NC}"
    fi

    # 3. Check for systemd service status
    echo -n "3. Checking for sing-box service: "
    if [ -f "$SERVICE_PATH" ]; then
        SERVICE_STATUS=$(systemctl is-active sing-box)
        if [ "$SERVICE_STATUS" == "active" ]; then
            echo -e "${GREEN}Active (Running)${NC}"
        else
            echo -e "${RED}Inactive (Status: $SERVICE_STATUS)${NC}"
        fi
    else
        echo -e "${RED}Not Found${NC}"
    fi
    echo "---------------------------------"
}

# --- Function to completely uninstall sing-box and configs ---
uninstall_ekray() {
    echo -e "${RED}WARNING: This will stop the sing-box service and REMOVE ALL related files (core, configs, users).${NC}"
    read -p "This action is irreversible. Are you sure you want to continue? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "Stopping and disabling sing-box service..."
        sudo systemctl stop sing-box &> /dev/null
        sudo systemctl disable sing-box &> /dev/null

        echo "Removing files..."
        sudo rm -f "$SERVICE_PATH"
        sudo rm -f "$SINGBOX_BIN_PATH"
        sudo rm -rf "/etc/sing-box/"

        sudo systemctl daemon-reload
        echo -e "${GREEN}EKray and sing-box core have been completely uninstalled.${NC}"
    else
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
    fi
}

# --- (Other functions like install_reality_service, add_reality_user etc. remain the same) ---
# --- For brevity, I'm only showing the new/changed functions. Use the full code from the previous version for the rest.
# --- The full code is available in the git history. We assume functions below are present.

install_reality_service() {
    if [ -f "$CONFIG_PATH" ]; then echo -e "${RED}A configuration file already exists. Please uninstall first if you want a clean setup.${NC}"; return; fi
    echo -e "${YELLOW}Installing VLESS+Reality Service...${NC}"; read -p "Enter the listen port (e.g., 443): " listen_port; read -p "Enter the SNI domain (e.g., www.microsoft.com): " server_name
    echo "Generating Reality key pair..."; REALITY_KEYS=$(/usr/local/bin/sing-box generate reality-keypair); PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}' | tr -d '",'); PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}' | tr -d '",')
    first_user_uuid=$(/usr/local/bin/sing-box generate uuid); first_user_name="initial-user"
    sudo bash -c "cat > $CONFIG_PATH" << EOF
{ "log": { "level": "info", "timestamp": true }, "inbounds": [ { "type": "vless", "tag": "vless-reality-in", "listen": "::", "listen_port": ${listen_port}, "users": [ { "uuid": "${first_user_uuid}", "flow": "xtls-rprx-vision" } ], "transport": { "type": "tcp" }, "tls": { "enabled": true, "server_name": "${server_name}", "reality": { "enabled": true, "handshake": { "server": "${server_name}", "server_port": 443 }, "private_key": "${PRIVATE_KEY}", "short_id": "" } } } ], "outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ] }
EOF
    echo "$PUBLIC_KEY" | sudo tee /etc/sing-box/reality.pub > /dev/null; echo "${first_user_name}:${first_user_uuid}" | sudo tee "$USER_DB_PATH" > /dev/null
    sudo systemctl restart sing-box; sleep 2; check_service_status; echo -e "${GREEN}Reality service installed and started successfully!${NC}"; echo "Generating connection info for the first user..."; generate_reality_link "$first_user_name" "$first_user_uuid"
}
add_reality_user() {
    if [ ! -f "$CONFIG_PATH" ]; then echo -e "${RED}Config not found. Install a service first.${NC}"; return; fi
    read -p "Enter a name for the new user (for identification): " user_name; new_uuid=$(/usr/local/bin/sing-box generate uuid)
    tmp_json=$(mktemp); jq --arg uuid "$new_uuid" '.inbounds[0].users += [{"uuid": $uuid, "flow": "xtls-rprx-vision"}]' "$CONFIG_PATH" > "$tmp_json"; sudo mv "$tmp_json" "$CONFIG_PATH"
    echo "${user_name}:${new_uuid}" | sudo tee -a "$USER_DB_PATH" > /dev/null
    sudo systemctl restart sing-box; sleep 2; echo -e "${GREEN}User '$user_name' with UUID '$new_uuid' added successfully.${NC}"; generate_reality_link "$user_name" "$new_uuid"
}
list_reality_users() {
    if [ ! -f "$USER_DB_PATH" ]; then echo -e "${RED}No users found or database is missing.${NC}"; return; fi; echo -e "${YELLOW}--- List of Reality Users ---${NC}"; i=1
    while IFS=: read -r name uuid; do echo -e "  ${GREEN}${i})${NC} Name: ${YELLOW}${name}${NC}\n     UUID: ${uuid}\n--------------------------"; ((i++)); done < <(sudo cat "$USER_DB_PATH")
}
generate_reality_link() {
    local user_name=$1; local uuid=$2; local server_ip=$(curl -s ip.me); local port=$(jq '.inbounds[0].listen_port' $CONFIG_PATH); local sni=$(jq -r '.inbounds[0].tls.server_name' $CONFIG_PATH); local pbk=$(sudo cat /etc/sing-box/reality.pub); local sid=$(jq -r '.inbounds[0].tls.reality.short_id' $CONFIG_PATH)
    VLESS_LINK="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#EKray-${user_name}"
    echo ""; echo -e "${YELLOW}Connection Link:${NC}"; echo "$VLESS_LINK"; echo ""; echo -e "${YELLOW}QR Code:${NC}"; qrencode -t ANSIUTF8 "$VLESS_LINK"
}
check_service_status() { sudo systemctl status sing-box --no-pager -l; }
install_singbox() { echo "This function needs to be added from v0.6.1"; } # Placeholder

# --- Main application loop ---
check_dependencies
while true; do
    show_main_menu
    read -p "Enter your choice [1-6]: " choice

    case $choice in
        1) update_server ;;
        2) install_singbox ;;
        3) service_management_menu ;;
        4) system_status_check ;;
        5) uninstall_ekray ;;
        6) echo "Exiting the panel..."; exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 2 ;;
    esac

    # After an action, prompt to return
    if [[ "$choice" -ne 3 && "$choice" -ne 6 ]]; then
        read -n 1 -s -r -p "Press any key to return to the main menu..."
    fi
done
