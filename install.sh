#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 2.0.0 (The Phoenix Release - Stable & Fully Featured)
# Author: Kaveh & Edward
# GitHub: https://github.com/edwardium/EKray.git
# =================================================================

# --- Style & Color Definitions ---
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'; C_B_GREEN='\033[1;32m'

# --- Paths ---
CONFIG_PATH="/etc/sing-box/config.json"
USER_DB_PATH="/etc/sing-box/users.db"
PUB_KEY_PATH="/etc/sing-box/reality.pub"
SINGBOX_BIN_PATH="/usr/local/bin/sing-box"
SERVICE_PATH="/etc/systemd/system/sing-box.service"

#=================================================
# ALL FUNCTION DEFINITIONS (DEFINED BEFORE USE)
#=================================================

# --- Helper Functions ---
press_any_key() { echo ""; read -n 1 -s -r -p "Press any key to return..."; }
print_header() {
    local title="$1"; local title_len=${#title}; local padding_len=$(( (45 - title_len) / 2 ))
    printf "\n${C_B_GREEN}┌─────────────────────────────────────────────┐${C_RESET}\n"
    printf "${C_B_GREEN}│%*s%s%*s│${C_RESET}\n" "$padding_len" "" "$title" "$((45 - title_len - padding_len))" ""
    printf "${C_B_GREEN}└─────────────────────────────────────────────┘${C_RESET}\n"
}
check_dependencies() { DEPS="curl jq qrencode openssl"; for dep in $DEPS; do if ! command -v "$dep" &> /dev/null; then echo -e "${C_YELLOW}Installing dependency: $dep...${C_RESET}"; sudo apt-get update -y && sudo apt-get install -y "$dep"; fi; done; }

# --- Core Logic Functions ---
initialize_config_if_needed() {
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\n${C_YELLOW}Initializing new config file...${C_RESET}"
        sudo bash -c "cat > $CONFIG_PATH" << EOF
{ "log": { "level": "info", "timestamp": true }, "inbounds": [], "outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ] }
EOF
        if [ $? -ne 0 ]; then echo -e "${C_RED}Failed to create config file.${C_RESET}"; return 1; fi
    fi
    return 0
}

update_server() { echo -e "\n${C_YELLOW}Updating server...${C_RESET}"; if sudo apt-get update -y && sudo apt-get upgrade -y; then echo -e "${C_B_GREEN}Server updated successfully!${C_RESET}"; else echo -e "${C_RED}An error occurred.${C_RESET}"; fi; }

install_singbox() {
    if command -v sing-box &> /dev/null; then echo -e "\n${C_GREEN}sing-box is already installed.${C_RESET}"; return; fi
    echo -e "\n${C_YELLOW}Installing sing-box...${C_RESET}"; local ARCH=$(uname -m); case "$ARCH" in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; *) echo -e "${C_RED}Unsupported architecture${C_RESET}"; return 1 ;; esac
    local LATEST_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name'); if [ -z "$LATEST_VERSION" ]; then echo -e "${C_RED}Error getting latest version.${C_RESET}"; return 1; fi
    echo "Latest version: $LATEST_VERSION"; local DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/$LATEST_VERSION/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"
    echo "Downloading..."; if ! curl -sLo sing-box.tar.gz "$DOWNLOAD_URL"; then echo -e "${C_RED}Download failed.${C_RESET}"; return 1; fi
    local EXTRACT_DIR="sing-box-${LATEST_VERSION#v}-linux-${ARCH}"; tar -xzf sing-box.tar.gz; sudo install -m 755 "${EXTRACT_DIR}/sing-box" "$SINGBOX_BIN_PATH"; sudo mkdir -p /etc/sing-box/; rm -rf "${EXTRACT_DIR}" sing-box.tar.gz
    if [ ! -f "$SERVICE_PATH" ]; then create_service_file; fi; echo -e "${C_B_GREEN}sing-box core installed successfully.${C_RESET}"
}

create_service_file() { echo -e "${C_YELLOW}Creating systemd service file...${C_RESET}"; SERVICE_FILE_CONTENT="[Unit]\nDescription=sing-box service\nAfter=network.target\n\n[Service]\nUser=root\nWorkingDirectory=/etc/sing-box\nCapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\nAmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\nExecStart=${SINGBOX_BIN_PATH} run -c ${CONFIG_PATH}\nRestart=on-failure\nRestartSec=10\nLimitNOFILE=infinity\n\n[Install]\nWantedBy=multi-user.target"; echo -e "$SERVICE_FILE_CONTENT" | sudo tee "$SERVICE_PATH" > /dev/null; sudo systemctl daemon-reload; sudo systemctl enable sing-box; echo -e "${C_GREEN}Service file created and enabled.${C_RESET}"; }

system_status_check() {
    echo -e "\n${C_YELLOW}--- System Status Check ---${C_RESET}"
    echo -n "1. Core: "; if [ -f "$SINGBOX_BIN_PATH" ]; then echo -e "${C_GREEN}Installed ($($SINGBOX_BIN_PATH version | awk '{print $3}'))${C_RESET}"; else echo -e "${C_RED}Not Found${C_RESET}"; fi
    echo -n "2. Config Dir: "; if [ -d "/etc/sing-box" ]; then echo -e "${C_GREEN}Found${C_RESET}"; else echo -e "${C_RED}Not Found${C_RESET}"; fi
    echo -n "3. Service: "; if [ -f "$SERVICE_PATH" ]; then SERVICE_STATUS=$(systemctl is-active sing-box); if [ "$SERVICE_STATUS" == "active" ]; then echo -e "${C_GREEN}Active (Running)${C_RESET}"; else echo -e "${C_RED}Inactive (Status: $SERVICE_STATUS)${C_RESET}"; fi; else echo -e "${C_RED}Not Found${C_RESET}"; fi
    echo "---------------------------"
}

uninstall_ekray() { echo -e "\n${C_RED}WARNING: This will REMOVE ALL EKray files.${C_RESET}"; read -p "Are you sure? (y/n): " confirm; if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then sudo systemctl stop sing-box &> /dev/null; sudo systemctl disable sing-box &> /dev/null; sudo rm -f "$SERVICE_PATH"; sudo rm -f "$SINGBOX_BIN_PATH"; sudo rm -rf "/etc/sing-box/"; sudo systemctl daemon-reload; echo -e "\n${C_B_GREEN}EKray and sing-box core have been completely uninstalled.${C_RESET}"; else echo -e "\n${C_YELLOW}Uninstall cancelled.${C_RESET}"; fi; }

delete_all_service_configs() {
    if [ ! -f "$CONFIG_PATH" ]; then echo -e "\n${C_YELLOW}No service configuration found to delete.${C_RESET}"; return; fi
    echo -e "\n${C_RED}WARNING: This will delete ALL protocol configurations and users.${C_RESET}"; read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        sudo systemctl stop sing-box
        sudo rm -f "$CONFIG_PATH" "$USER_DB_PATH" "$PUB_KEY_PATH" &> /dev/null
        initialize_config_if_needed &> /dev/null
        echo -e "\n${C_GREEN}All protocol configurations and users have been deleted.${C_RESET}"
    else
        echo -e "\n${C_YELLOW}Deletion cancelled.${C_RESET}"
    fi
}

install_reality_service() {
    initialize_config_if_needed || return
    if jq -e '.inbounds[] | select(.tag == "vless-reality-in")' "$CONFIG_PATH" > /dev/null; then echo -e "\n${C_RED}Reality service is already installed.${C_RESET}"; return; fi
    echo -e "\n${C_YELLOW}Installing VLESS+Reality...${C_RESET}"; read -p "Enter listen port (default: 443): " listen_port; listen_port=${listen_port:-443}; read -p "Enter SNI domain (default: www.microsoft.com): " server_name; server_name=${server_name:-www.microsoft.com}
    echo "Generating Reality key pair..."; REALITY_KEYS=$($SINGBOX_BIN_PATH generate reality-keypair); PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}' | tr -d '",'); PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}' | tr -d '",'); RANDOM_SHORT_ID=$(openssl rand -hex 8)
    REALITY_INBOUND=$(jq -n --argjson port "$listen_port" --arg sni "$server_name" --arg p_key "$PRIVATE_KEY" --arg s_id "$RANDOM_SHORT_ID" '{ "type": "vless", "tag": "vless-reality-in", "listen": "::", "listen_port": $port, "users": [], "tls": { "enabled": true, "server_name": $sni, "reality": { "enabled": true, "handshake": { "server": $sni, "server_port": 443 }, "private_key": $p_key, "short_id": $s_id } } }'); tmp_json=$(mktemp); jq --argjson new_inbound "$REALITY_INBOUND" '.inbounds += [$new_inbound]' "$CONFIG_PATH" > "$tmp_json"; sudo mv "$tmp_json" "$CONFIG_PATH"; echo "$PUBLIC_KEY" | sudo tee "$PUB_KEY_PATH" > /dev/null
    echo -e "\n${C_GREEN}Reality inbound added. Restarting service...${C_RESET}"; sudo systemctl restart sing-box; sleep 1; echo "Service status after installation:"; system_status_check
}

install_hysteria2_service() {
    initialize_config_if_needed || return
    if jq -e '.inbounds[] | select(.tag == "hysteria2-in")' "$CONFIG_PATH" > /dev/null; then echo -e "\n${C_RED}Hysteria2 service is already installed.${C_RESET}"; return; fi
    echo -e "\n${C_YELLOW}Installing Hysteria2...${C_RESET}"; read -p "Enter listen port (e.g., 34567): " listen_port; read -p "Enter a password: " hy2_password
    HYSTERIA2_INBOUND=$(jq -n --argjson port "$listen_port" --arg pass "$hy2_password" '{ "type": "hysteria2", "tag": "hysteria2-in", "listen": "::", "listen_port": $port, "users": [ { "password": $pass } ], "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/sing-box/self-signed.crt", "key_path": "/etc/sing-box/self-signed.key" } }');
    if [ ! -f "/etc/sing-box/self-signed.crt" ]; then echo "Generating self-signed certificate..."; sudo openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/sing-box/self-signed.key -out /etc/sing-box/self-signed.crt -subj "/CN=localhost" -days 3650 &> /dev/null; fi
    tmp_json=$(mktemp); jq --argjson new_inbound "$HYSTERIA2_INBOUND" '.inbounds += [$new_inbound]' "$CONFIG_PATH" > "$tmp_json"; sudo mv "$tmp_json" "$CONFIG_PATH"
    echo -e "\n${C_GREEN}Hysteria2 inbound added. Restarting service...${C_RESET}"; sudo systemctl restart sing-box; sleep 1; echo "Service status after installation:"; system_status_check
}

add_reality_user() {
    if ! jq -e '.inbounds[] | select(.tag == "vless-reality-in")' "$CONFIG_PATH" > /dev/null; then echo -e "\n${C_RED}Reality service not installed. Please install it first.${C_RESET}"; return; fi
    read -p "Enter a name for the new user: " user_name; if [ -z "$user_name" ]; then echo -e "${C_RED}User name cannot be empty.${C_RESET}"; return; fi
    new_uuid=$($SINGBOX_BIN_PATH generate uuid); tmp_json=$(mktemp); jq --arg uuid "$new_uuid" '.inbounds[] | select(.tag == "vless-reality-in") | .users += [{"uuid": $uuid, "flow": "xtls-rprx-vision"}]' "$CONFIG_PATH" > "$tmp_json"; sudo mv "$tmp_json" "$CONFIG_PATH"
    echo "${user_name}:${new_uuid}" | sudo tee -a "$USER_DB_PATH" > /dev/null; sudo systemctl restart sing-box; sleep 1
    echo -e "\n${C_B_GREEN}User '${user_name}' added successfully!${C_RESET}"
    generate_reality_link "$user_name" "$new_uuid"
}

delete_single_user() {
    local user_name=$1; local user_uuid=$2
    echo -e "\n${C_RED}WARNING: You are about to delete user '${user_name}'.${C_RESET}"; read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo -e "\n${C_YELLOW}Deletion cancelled.${C_RESET}"; return; fi
    echo "Removing user from sing-box config..."; tmp_json=$(mktemp)
    jq --arg uuid "$user_uuid" '(.inbounds[] | select(.tag == "vless-reality-in")).users |= del(.[] | select(.uuid == $uuid))' "$CONFIG_PATH" > "$tmp_json"; sudo mv "$tmp_json" "$CONFIG_PATH"
    echo "Removing user from database..."; sudo sed -i "/${user_uuid}/d" "$USER_DB_PATH"
    echo "Restarting service..."; sudo systemctl restart sing-box; sleep 1
    echo -e "\n${C_B_GREEN}User '${user_name}' has been deleted successfully.${C_RESET}"
}

generate_reality_link() {
    local user_name=$1; local uuid=$2;
    if [ "$3" != "no_clear" ]; then clear; fi
    local server_ip=$(curl -4s ip.me); local port=$(jq '.inbounds[] | select(.tag == "vless-reality-in") | .listen_port' $CONFIG_PATH); local sni=$(jq -r '.inbounds[] | select(.tag == "vless-reality-in") | .tls.server_name' $CONFIG_PATH)
    local pbk=$(sudo cat "$PUB_KEY_PATH"); local sid=$(jq -r '.inbounds[] | select(.tag == "vless-reality-in") | .tls.reality.short_id' $CONFIG_PATH)
    VLESS_LINK="vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#EKray-${user_name}"

    print_header "👤 Connection Info: ${user_name}"
    echo -e " ${C_GREEN}Server IP:${C_RESET}         ${server_ip}"; echo -e " ${C_GREEN}Listen Port:${C_RESET}       ${port}"; echo -e " ${C_GREEN}User UUID:${C_RESET}         ${uuid}"; echo -e " ${C_GREEN}Server Name (SNI):${C_RESET} ${sni}"; echo -e " ${C_GREEN}Public Key:${C_RESET}        ${pbk}"; echo -e " ${C_GREEN}Short ID:${C_RESET}          ${sid}";
    echo "-----------------------------------------------"; echo -e " ${C_YELLOW}🔗 VLESS Link (for V2Ray, etc.):${C_RESET}"; echo "   $VLESS_LINK";
    echo "-----------------------------------------------"; echo -e " ${C_YELLOW}📱 QR Code (for mobile clients):${C_RESET}"; qrencode -t UTF8 -m 1 "$VLESS_LINK"; echo "==============================================="
}

list_and_manage_users() {
    if [ ! -f "$USER_DB_PATH" ] || ! [ -s "$USER_DB_PATH" ]; then echo -e "\n${C_RED}No users found. Please add a user first.${C_RESET}"; press_any_key; return; fi
    while true; do
        clear; print_header "📇 Manage Users"
        i=1; mapfile -t users < <(sudo cat "$USER_DB_PATH")
        for user_line in "${users[@]}"; do
            local name=$(echo "$user_line" | cut -d: -f1); local uuid=$(echo "$user_line" | cut -d: -f2)
            echo -e "  ${C_GREEN}${i})${C_RESET} Name: ${C_YELLOW}${name}${C_RESET}  (UUID: ${uuid:0:8}...)"
            ((i++))
        done
        echo "-----------------------------------------------"
        read -p "Enter user number to manage (or 0 to go back): " user_number
        if [[ "$user_number" == "0" ]]; then break; fi
        if ! [[ "$user_number" =~ ^[0-9]+$ ]] || [ "$user_number" -gt "${#users[@]}" ]; then echo -e "\n${C_RED}Invalid selection.${C_RESET}"; sleep 2; continue; fi
        local selected_user_line="${users[$((user_number-1))]}"; local user_name=$(echo "$selected_user_line" | cut -d: -f1); local user_uuid=$(echo "$selected_user_line" | cut -d: -f2)
        manage_single_user "$user_name" "$user_uuid"
    done
}

manage_single_user() {
    local user_name=$1; local user_uuid=$2
    while true; do
        clear; print_header "👤 Managing User: ${user_name}";
        echo "  1) View User Config / QR Code"; echo "  2) Delete User"; echo "  3) Back to User List"
        echo "-----------------------------------------------"; read -p "Enter choice [1-3]: " manage_choice
        case $manage_choice in
            1) generate_reality_link "$user_name" "$user_uuid" "no_clear"; press_any_key ;;
            2) delete_single_user "$user_name" "$user_uuid"; press_any_key; return ;;
            3) return ;;
            *) echo -e "\n${C_RED}Invalid option.${C_RESET}"; sleep 2 ;;
        esac
    done
}

view_service_logs() { echo -e "\n${C_YELLOW}Showing last 50 lines of sing-box logs...${C_RESET}"; sudo journalctl -u sing-box -n 50 --no-pager; }
validate_config_file() { if [ ! -f "$CONFIG_PATH" ]; then echo -e "\n${C_RED}No config file found to validate.${C_RESET}"; return; fi; echo -e "\n${C_YELLOW}Validating config...${C_RESET}"; sudo "$SINGBOX_BIN_PATH" check -c "$CONFIG_PATH"; }

#=================================================
# SCRIPT EXECUTION STARTS HERE
#=================================================
check_dependencies
main_menu
