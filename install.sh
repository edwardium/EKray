#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 1.2.0 (Multi-Protocol Architecture)
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
SINGBOX_BIN_PATH="/usr/local/bin/sing-box"
SERVICE_PATH="/etc/systemd/system/sing-box.service"

# --- Function to pause and wait for user input ---
press_any_key() { read -n 1 -s -r -p "Press any key to return to the menu..."; }

# --- Function to initialize the main config file if it doesn't exist ---
initialize_config_if_needed() {
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "${YELLOW}No config file found. Initializing a new one...${NC}"
        sudo bash -c "cat > $CONFIG_PATH" << EOF
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
EOF
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create initial config file.${NC}"; return 1
        fi
    fi
    return 0
}

# --- Main Menu Display Function ---
show_main_menu() {
    clear
    echo "============================================="
    echo "         EKray Management Panel v1.2.0       "
    echo "             by Edward & Kaveh             "
    echo "============================================="
    echo "Please choose an option:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Service Management"
    echo -e "  ${GREEN}2)${NC} System Maintenance"
    echo -e "  ${RED}3)${NC} Exit"
    echo ""
    echo "---------------------------------------------"
}

# --- Service Management Sub-menu ---
service_management_menu() {
    clear
    echo "============================================="
    echo "             Service Management              "
    echo "============================================="
    echo "  1) Protocol Management (Install/Delete)"
    echo "  2) User Management"
    echo "  3) Service Control (Start/Stop/Restart)"
    echo "  4) Diagnostics (Status/Logs/Check)"
    echo "  5) Back to Main Menu"
    echo "============================================="
    read -p "Enter your choice [1-5]: " choice
    case $choice in
        1) protocol_management_menu ;;
        2) user_management_menu ;;
        3) service_control_menu ;;
        4) diagnostics_menu ;;
        5) return ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 2 ;;
    esac
}

# --- Protocol Management Menu ---
protocol_management_menu() {
    clear; echo "--- Protocol Management ---"
    echo "  1) Install VLESS + Reality"
    echo "  2) Install Hysteria2"
    echo "  3) (Coming Soon) Install Trojan"
    echo "  4) (Coming Soon) Install VMess"
    echo "  5) Back"
    read -p "Choose a protocol to install: " choice
    case $choice in
        1) install_reality_service; press_any_key ;;
        2) install_hysteria2_service; press_any_key ;;
        5) return ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 2 ;;
    esac
}

# --- Function to install Reality service ---
install_reality_service() {
    initialize_config_if_needed || return

    if jq -e '.inbounds[] | select(.tag == "vless-reality-in")' "$CONFIG_PATH" > /dev/null; then
        echo -e "${RED}Reality service is already installed.${NC}"; return
    fi

    echo -e "${YELLOW}Installing VLESS+Reality Service...${NC}"
    read -p "Enter listen port (default: 443): " listen_port; listen_port=${listen_port:-443}
    read -p "Enter SNI domain (default: www.microsoft.com): " server_name; server_name=${server_name:-www.microsoft.com}

    REALITY_KEYS=$(/usr/local/bin/sing-box generate reality-keypair)
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}' | tr -d '",')
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}' | tr -d '",')
    RANDOM_SHORT_ID=$(openssl rand -hex 8)

    REALITY_INBOUND=$(jq -n \
        --argjson port "$listen_port" \
        --arg sni "$server_name" \
        --arg p_key "$PRIVATE_KEY" \
        --arg s_id "$RANDOM_SHORT_ID" \
        '{
            "type": "vless", "tag": "vless-reality-in", "listen": "::", "listen_port": $port,
            "users": [],
            "tls": {
                "enabled": true, "server_name": $sni,
                "reality": { "enabled": true, "handshake": { "server": $sni, "server_port": 443 }, "private_key": $p_key, "short_id": $s_id }
            }
        }')

    tmp_json=$(mktemp)
    jq --argjson new_inbound "$REALITY_INBOUND" '.inbounds += [$new_inbound]' "$CONFIG_PATH" > "$tmp_json"
    sudo mv "$tmp_json" "$CONFIG_PATH"
    echo "$PUBLIC_KEY" | sudo tee "/etc/sing-box/reality.pub" > /dev/null

    echo -e "${GREEN}Reality inbound added. Restarting service...${NC}"
    sudo systemctl restart sing-box; sleep 1; check_service_status
}

# --- Function to install Hysteria2 service ---
install_hysteria2_service() {
    initialize_config_if_needed || return

    if jq -e '.inbounds[] | select(.tag == "hysteria2-in")' "$CONFIG_PATH" > /dev/null; then
        echo -e "${RED}Hysteria2 service is already installed.${NC}"; return
    fi

    echo -e "${YELLOW}Installing Hysteria2 Service...${NC}"
    read -p "Enter listen port (e.g., 34567): " listen_port
    read -p "Enter a strong password for Hysteria2: " hy2_password

    HYSTERIA2_INBOUND=$(jq -n \
        --argjson port "$listen_port" \
        --arg pass "$hy2_password" \
        '{
            "type": "hysteria2", "tag": "hysteria2-in", "listen": "::", "listen_port": $port,
            "users": [ { "password": $pass } ],
            "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/sing-box/self-signed.crt", "key_path": "/etc/sing-box/self-signed.key" }
        }')

    # Generate self-signed certs for Hysteria2 if they don't exist
    if [ ! -f "/etc/sing-box/self-signed.crt" ]; then
        echo "Generating self-signed certificate for Hysteria2..."
        sudo openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/sing-box/self-signed.key -out /etc/sing-box/self-signed.crt -subj "/CN=localhost" -days 3650
    fi

    tmp_json=$(mktemp)
    jq --argjson new_inbound "$HYSTERIA2_INBOUND" '.inbounds += [$new_inbound]' "$CONFIG_PATH" > "$tmp_json"
    sudo mv "$tmp_json" "$CONFIG_PATH"

    echo -e "${GREEN}Hysteria2 inbound added. Restarting service...${NC}"
    sudo systemctl restart sing-box; sleep 1; check_service_status
}


# --- Placeholder for other functions for brevity. The full code would be much larger. ---
user_management_menu() { echo "User management is being refactored for multi-protocol support."; sleep 2; }
service_control_menu() { echo "Service control is under development."; sleep 2; }
diagnostics_menu() { echo "Diagnostics are under development."; sleep 2; }
system_maintenance_menu() {
    clear; echo "--- System Maintenance ---"
    echo "  1) Update Server & Dependencies"
    echo "  2) Install/Update sing-box Core"
    echo "  3) System Status Check"
    echo "  4) Uninstall EKray & Core"
    echo "  5) Back"
    read -p "Choose an option: " choice
    case $choice in
        1) update_server; press_any_key ;;
        2) install_singbox; press_any_key ;;
        3) system_status_check; press_any_key ;;
        4) uninstall_ekray; press_any_key ;;
        5) return ;;
    esac
}
update_server() { echo -e "${YELLOW}Updating server...${NC}"; sudo apt-get update && sudo apt-get upgrade -y; echo -e "${GREEN}Server updated.${NC}"; }
install_singbox() { if command -v sing-box &> /dev/null; then echo -e "${GREEN}sing-box is already installed.${NC}"; return; fi; echo -e "${YELLOW}Installing sing-box...${NC}"; local ARCH=$(uname -m); case "$ARCH" in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; *) echo -e "${RED}Unsupported architecture${NC}"; return 1 ;; esac; local LATEST_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name'); if [ -z "$LATEST_VERSION" ]; then echo -e "${RED}Error getting latest version.${NC}"; return 1; fi; echo "Latest version: $LATEST_VERSION"; local DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/$LATEST_VERSION/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"; echo "Downloading..."; curl -sLo sing-box.tar.gz "$DOWNLOAD_URL"; if [ $? -ne 0 ]; then echo -e "${RED}Download failed.${NC}"; return 1; fi; local EXTRACT_DIR="sing-box-${LATEST_VERSION#v}-linux-${ARCH}"; tar -xzf sing-box.tar.gz; sudo install -m 755 "${EXTRACT_DIR}/sing-box" "$SINGBOX_BIN_PATH"; sudo mkdir -p /etc/sing-box/; rm -rf "${EXTRACT_DIR}" sing-box.tar.gz; if [ ! -f "$SERVICE_PATH" ]; then create_service_file; fi; echo -e "${GREEN}sing-box core installed.${NC}"; }
check_service_status() { sudo systemctl status sing-box --no-pager -l; }

# --- Main application loop ---
check_dependencies
while true; do
    show_main_menu
    read -p "Enter your choice [1-3]: " choice

    case $choice in
        1) service_management_menu ;;
        2) system_maintenance_menu ;;
        3) echo "Exiting the panel..."; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 2 ;;
    esac
done
