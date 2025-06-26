#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 1.1.0 (Interactive User Management)
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
PUB_KEY_PATH="/etc/sing-box/reality.pub"
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
    echo "         EKray Management Panel v1.1.0       "
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

# --- Service Management Sub-menu (Reordered as requested) ---
service_management_menu() {
    while true; do
        clear
        echo "============================================="
        echo "             Service Management              "
        echo "============================================="
        echo " --- Protocol Management ---"
        echo "  1) Install Reality Service"
        echo "  2) Add Reality User"
        echo "  3) List / Manage Reality Users"
        echo "  4) Delete All Reality Service & Users"
        echo " -------------------------------------------"
        echo " --- Service Control ---"
        echo "  5) Start Service"
        echo "  6) Stop Service"
        echo "  7) Restart Service"
        echo " -------------------------------------------"
        echo " --- Status & Logs ---"
        echo "  8) View Service Status"
        echo "  9) View Service Logs"
        echo "  10) Validate Config File"
        echo " -------------------------------------------"
        echo "  11) Back to Main Menu"
        echo "============================================="
        read -p "Enter your choice [1-11]: " service_choice

        case $service_choice in
            1) install_reality_service ;;
            2) add_reality_user ;;
            3) list_and_manage_users ;;
            4) delete_all_reality_service ;;
            5) sudo systemctl start sing-box; echo -e "\n${GREEN}Service start command sent.${NC}" ;;
            6) sudo systemctl stop sing-box; echo -e "\n${GREEN}Service stop command sent.${NC}" ;;
            7) sudo systemctl restart sing-box; echo -e "\n${GREEN}Service restart command sent.${NC}" ;;
            8) check_service_status ;;
            9) view_service_logs ;;
            10) validate_config_file ;;
            11) return ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 2 ;;
        esac

        if [[ "$service_choice" -ne 11 ]]; then
            read -n 1 -s -r -p "Press any key to return to the service menu..."
        fi
    done
}

# --- New: Interactive User Management Flow ---
list_and_manage_users() {
    if [ ! -f "$USER_DB_PATH" ]; then
        echo -e "${RED}No users found. Please add a user first.${NC}"; return
    fi

    clear
    echo -e "${YELLOW}--- List of Reality Users ---${NC}"
    i=1
    # Store users in an array for easy access
    mapfile -t users < <(sudo cat "$USER_DB_PATH")

    for user_line in "${users[@]}"; do
        local name=$(echo "$user_line" | cut -d: -f1)
        local uuid=$(echo "$user_line" | cut -d: -f2)
        echo -e "  ${GREEN}${i})${NC} Name: ${YELLOW}${name}${NC}  (UUID: ${uuid:0:8}...)"
        ((i++))
    done
    echo "---------------------------------"
    read -p "Enter user number to manage (or 0 to go back): " user_number

    if [[ "$user_number" -eq 0 ]]; then return; fi
    if ! [[ "$user_number" =~ ^[0-9]+$ ]] || [ "$user_number" -gt "${#users[@]}" ]; then
        echo -e "${RED}Invalid selection.${NC}"; sleep 2; return
    fi

    local selected_user_line="${users[$((user_number-1))]}"
    local user_name=$(echo "$selected_user_line" | cut -d: -f1)
    local user_uuid=$(echo "$selected_user_line" | cut -d: -f2)

    manage_single_user "$user_name" "$user_uuid"
}

# --- New: Sub-menu for a single user ---
manage_single_user() {
    local user_name=$1
    local user_uuid=$2

    clear
    echo "============================================="
    echo -e "  Managing User: ${YELLOW}${user_name}${NC}"
    echo "============================================="
    echo "  1) View User Config / QR Code"
    echo "  2) Delete User"
    echo "  3) Back"
    echo "---------------------------------------------"
    read -p "Enter your choice [1-3]: " manage_choice

    case $manage_choice in
        1) generate_reality_link "$user_name" "$user_uuid" "no_clear" ;;
        2) delete_single_user "$user_name" "$user_uuid" ;;
        3) return ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 2 ;;
    esac
}

# --- New: Function to delete a single user ---
delete_single_user() {
    local user_name=$1
    local user_uuid=$2

    echo -e "${RED}WARNING: You are about to delete user '${user_name}'. This cannot be undone.${NC}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Deletion cancelled.${NC}"; return
    fi

    # Delete from config.json
    echo "Removing user from sing-box config..."
    tmp_json=$(mktemp)
    jq --arg uuid "$user_uuid" 'del(.inbounds[0].users[] | select(.uuid == $uuid))' "$CONFIG_PATH" > "$tmp_json"
    sudo mv "$tmp_json" "$CONFIG_PATH"

    # Delete from users.db
    echo "Removing user from database..."
    sudo sed -i "/${user_uuid}/d" "$USER_DB_PATH"

    echo "Restarting service..."
    sudo systemctl restart sing-box
    sleep 2

    echo -e "${GREEN}User '${user_name}' has been deleted successfully.${NC}"
}


# --- Function to generate and display Reality link with full details ---
generate_reality_link() {
    local user_name=$1
    local uuid=$2

    if [ "$3" != "no_clear" ]; then clear; fi

    local server_ip=$(curl -s ip.me); local port=$(jq '.inbounds[0].listen_port' $CONFIG_PATH); local sni=$(jq -r '.inbounds[0].tls.server_name' $CONFIG_PATH); local pbk=$(sudo cat "$PUB_KEY_PATH"); local sid=$(jq -r '.inbounds[0].tls.reality.short_id' $CONFIG_PATH);
    VLESS_LINK="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#EKray-${user_name}"

    echo "============================================="; echo -e "  Connection Info for User: ${YELLOW}${user_name}${NC}"; echo "============================================="
    echo -e "${GREEN}Server IP:${NC}         ${server_ip}"; echo -e "${GREEN}Listen Port:${NC}       ${port}"; echo -e "${GREEN}User UUID:${NC}         ${uuid}"; echo -e "${GREEN}Server Name (SNI):${NC} ${sni}"; echo -e "${GREEN}Public Key:${NC}        ${pbk}"; echo -e "${GREEN}Short ID:${NC}          ${sid}";
    echo "---------------------------------------------"; echo -e "${YELLOW}VLESS Link (for V2Ray, etc.):${NC}"; echo "$VLESS_LINK";
    echo "---------------------------------------------"; echo -e "${YELLOW}QR Code (for mobile clients):${NC}"; qrencode -t UTF8 -m 1 "$VLESS_LINK"; echo "============================================="
}

# (The rest of the script is unchanged and included for completeness)
install_singbox() { if command -v sing-box &> /dev/null; then echo -e "${GREEN}sing-box is already installed.${NC}"; return; fi; echo -e "${YELLOW}Installing sing-box...${NC}"; local ARCH=$(uname -m); case "$ARCH" in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; *) echo -e "${RED}Unsupported architecture${NC}"; return 1 ;; esac; local LATEST_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name'); if [ -z "$LATEST_VERSION" ]; then echo -e "${RED}Error getting latest version.${NC}"; return 1; fi; echo "Latest version: $LATEST_VERSION"; local DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/$LATEST_VERSION/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"; echo "Downloading..."; curl -sLo sing-box.tar.gz "$DOWNLOAD_URL"; if [ $? -ne 0 ]; then echo -e "${RED}Download failed.${NC}"; return 1; fi; local EXTRACT_DIR="sing-box-${LATEST_VERSION#v}-linux-${ARCH}"; tar -xzf sing-box.tar.gz; sudo install -m 755 "${EXTRACT_DIR}/sing-box" "$SINGBOX_BIN_PATH"; sudo mkdir -p /etc/sing-box/; rm -rf "${EXTRACT_DIR}" sing-box.tar.gz; if [ ! -f "$SERVICE_PATH" ]; then create_service_file; fi; echo -e "${GREEN}sing-box core installed.${NC}"; }
create_service_file() { echo -e "${YELLOW}Creating systemd service file...${NC}"; SERVICE_FILE_CONTENT="[Unit]\nDescription=sing-box service\nAfter=network.target\n\n[Service]\nUser=root\nWorkingDirectory=/etc/sing-box\nCapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\nAmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\nExecStart=${SINGBOX_BIN_PATH} run -c ${CONFIG_PATH}\nRestart=on-failure\nRestartSec=10\nLimitNOFILE=infinity\n\n[Install]\nWantedBy=multi-user.target"; echo -e "$SERVICE_FILE_CONTENT" | sudo tee "$SERVICE_PATH" > /dev/null; sudo systemctl daemon-reload; sudo systemctl enable sing-box; echo -e "${GREEN}Service file created.${NC}"; }
update_server() { echo -e "${YELLOW}Updating server...${NC}"; sudo apt-get update && sudo apt-get upgrade -y; echo -e "${GREEN}Server updated.${NC}"; }
system_status_check() { echo -e "${YELLOW}--- System Status ---${NC}"; echo -n "1. Core: "; if [ -f "$SINGBOX_BIN_PATH" ]; then echo -e "${GREEN}Installed ($($SINGBOX_BIN_PATH version | awk '{print $3}'))${NC}"; else echo -e "${RED}Not Found${NC}"; fi; echo -n "2. Config Dir: "; if [ -d "/etc/sing-box" ]; then echo -e "${GREEN}Found${NC}"; else echo -e "${RED}Not Found${NC}"; fi; echo -n "3. Service: "; if [ -f "$SERVICE_PATH" ]; then SERVICE_STATUS=$(systemctl is-active sing-box); if [ "$SERVICE_STATUS" == "active" ]; then echo -e "${GREEN}Active (Running)${NC}"; else echo -e "${RED}Inactive (Status: $SERVICE_STATUS)${NC}"; fi; else echo -e "${RED}Not Found${NC}"; fi; echo "-------------------"; }
uninstall_ekray() { echo -e "${RED}WARNING: This will REMOVE ALL EKray files.${NC}"; read -p "Are you sure? (y/n): " confirm; if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then sudo systemctl stop sing-box &> /dev/null; sudo systemctl disable sing-box &> /dev/null; sudo rm -f "$SERVICE_PATH"; sudo rm -f "$SINGBOX_BIN_PATH"; sudo rm -rf "/etc/sing-box/"; sudo systemctl daemon-reload; echo -e "${GREEN}EKray uninstalled.${NC}"; else echo -e "${YELLOW}Cancelled.${NC}"; fi; }
delete_all_reality_service() { if [ ! -f "$CONFIG_PATH" ]; then echo -e "${YELLOW}No service to delete.${NC}"; return; fi; echo -e "${RED}WARNING: This will delete the current Reality config & all users.${NC}"; read -p "Are you sure? (y/n): " confirm; if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then sudo systemctl stop sing-box; sudo rm -f "$CONFIG_PATH" "$USER_DB_PATH" "$PUB_KEY_PATH"; echo -e "${GREEN}Reality config deleted.${NC}"; else echo -e "${YELLOW}Cancelled.${NC}"; fi; }
install_reality_service() { if [ -f "$CONFIG_PATH" ]; then echo -e "${RED}A config file exists. Delete it first.${NC}"; return; fi; echo -e "${YELLOW}Installing VLESS+Reality...${NC}"; read -p "Enter listen port: " listen_port; read -p "Enter SNI domain: " server_name; echo "Generating keys..."; REALITY_KEYS=$(/usr/local/bin/sing-box generate reality-keypair); PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}' | tr -d '",'); PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}' | tr -d '",'); first_user_uuid=$(/usr/local/bin/sing-box generate uuid); first_user_name="initial-user"; sudo bash -c "cat > $CONFIG_PATH" << EOF
{ "log": { "level": "info", "timestamp": true }, "inbounds": [ { "type": "vless", "tag": "vless-reality-in", "listen": "::", "listen_port": ${listen_port}, "users": [ { "uuid": "${first_user_uuid}", "flow": "xtls-rprx-vision" } ], "tls": { "enabled": true, "server_name": "${server_name}", "reality": { "enabled": true, "handshake": { "server": "${server_name}", "server_port": 443 }, "private_key": "${PRIVATE_KEY}", "short_id": "" } } } ], "outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ] }
EOF
    echo "$PUBLIC_KEY" | sudo tee "$PUB_KEY_PATH" > /dev/null; echo "${first_user_name}:${first_user_uuid}" | sudo tee "$USER_DB_PATH" > /dev/null; if sudo "$SINGBOX_BIN_PATH" check -c "$CONFIG_PATH"; then echo -e "${GREEN}Config is valid. Restarting...${NC}"; sudo systemctl restart sing-box; sleep 1; if systemctl is-active --quiet sing-box; then echo -e "${GREEN}Service started successfully!${NC}"; generate_reality_link "$first_user_name" "$first_user_uuid"; else echo -e "${RED}Service failed to start.${NC}"; fi; else echo -e "${RED}Generated config is invalid.${NC}"; fi; }
add_reality_user() { if [ ! -f "$CONFIG_PATH" ]; then echo -e "${RED}Config not found.${NC}"; return; fi; read -p "Enter a name for the new user: " user_name; new_uuid=$(/usr/local/bin/sing-box generate uuid); tmp_json=$(mktemp); jq --arg uuid "$new_uuid" '.inbounds[0].users += [{"uuid": $uuid, "flow": "xtls-rprx-vision"}]' "$CONFIG_PATH" > "$tmp_json"; sudo mv "$tmp_json" "$CONFIG_PATH"; echo "${user_name}:${new_uuid}" | sudo tee -a "$USER_DB_PATH" > /dev/null; sudo systemctl restart sing-box; sleep 2; echo -e "${GREEN}User '$user_name' added.${NC}"; generate_reality_link "$user_name" "$user_uuid"; }
validate_config_file() { if [ ! -f "$CONFIG_PATH" ]; then echo -e "${RED}No config file found.${NC}"; return; fi; echo -e "${YELLOW}Validating config...${NC}"; sudo "$SINGBOX_BIN_PATH" check -c "$CONFIG_PATH"; }
check_service_status() { sudo systemctl status sing-box --no-pager -l; }
view_service_logs() { echo -e "${YELLOW}Last 50 lines of logs...${NC}"; sudo journalctl -u sing-box -n 50 --no-pager; }

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

    if [[ "$choice" -ne 3 && "$choice" -ne 6 ]]; then
        read -n 1 -s -r -p "Press any key to return to the main menu..."
    fi
done
