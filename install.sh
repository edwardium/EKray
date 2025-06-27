#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 3.0.1 (Variable Scope Hotfix & Stability)
# Author: Kaveh & Edward
# GitHub: https://github.com/edwardium/EKray.git
# =================================================================

# --- Style & Color Definitions ---
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'; C_B_GREEN='\033[1;32m'

# --- Paths ---
WORK_DIR="/etc/ekray"
CONFIG_PATH="${WORK_DIR}/sing-box-config.json"
VARS_PATH="${WORK_DIR}/ekray_vars.conf" # Central file for variables
NGINX_CONFIG_PATH="/etc/nginx/nginx.conf"
SUBSCRIPTION_PATH="${WORK_DIR}/sub.txt"
SINGBOX_BIN_PATH="/usr/local/bin/sing-box"
CLOUDFLARED_BIN_PATH="/usr/local/bin/cloudflared"

#=================================================
# ALL FUNCTION DEFINITIONS
#=================================================

# --- Helper Functions ---
press_any_key() { echo ""; read -n 1 -s -r -p "Press any key to return..."; }
print_header() {
    local title="$1"; local title_len=${#title}; local padding_len=$(( (45 - title_len) / 2 ))
    printf "\n${C_B_GREEN}┌─────────────────────────────────────────────┐${C_RESET}\n"
    printf "${C_B_GREEN}│%*s%s%*s│${C_RESET}\n" "$padding_len" "" "$title" "$((45 - title_len - padding_len))" ""
    printf "${C_B_GREEN}└─────────────────────────────────────────────┘${C_RESET}\n"
}
manage_packages() {
    local action=$1; shift; for package in "$@"; do if [ "$action" == "install" ]; then if command -v "$package" &>/dev/null; then continue; fi
    echo -e "${C_YELLOW}Installing package: $package...${C_RESET}"; if command -v apt-get &>/dev/null; then sudo apt-get-get update -y >/dev/null && sudo apt-get-get install -y "$package"
    elif command -v dnf &>/dev/null; then sudo dnf install -y "$package"; elif command -v yum &>/dev/null; then sudo yum install -y "$package"; else echo -e "${C_RED}Unsupported package manager.${C_RESET}"; return 1; fi; fi; done
}
check_dependencies() { manage_packages install curl jq qrencode openssl nginx; }
get_server_ip() { curl -4s https://ip.me || curl -4s ifconfig.me; }

# --- Core Installation Logic ---
install_all_in_one() {
    if [ -f "$CONFIG_PATH" ]; then echo -e "\n${C_RED}EKray is already installed. Uninstall first.${C_RESET}"; return; fi
    print_header "🚀 Starting All-in-One Installation"

    echo -e "${C_YELLOW}Step 1: Installing dependencies...${C_RESET}"; check_dependencies
    echo -e "\n${C_YELLOW}Step 2: Installing Core Engines...${C_RESET}"; local ARCH; case "$(uname -m)" in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; *) echo -e "${C_RED}Unsupported architecture${C_RESET}"; return 1 ;; esac

    echo "Downloading sing-box..."; local LATEST_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r '.tag_name'); local SINGBOX_URL="https://github.com/SagerNet/sing-box/releases/download/$LATEST_VERSION/sing-box-${LATEST_VERSION#v}-linux-${ARCH}.tar.gz"
    curl -sLo sing-box.tar.gz "$SINGBOX_URL"; tar -xzf sing-box.tar.gz; sudo install -m 755 "sing-box-${LATEST_VERSION#v}-linux-${ARCH}/sing-box" "$SINGBOX_BIN_PATH"

    echo "Downloading cloudflared..."; local CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"; sudo curl -sL "$CLOUDFLARED_URL" -o "$CLOUDFLARED_BIN_PATH"; sudo chmod +x "$CLOUDFLARED_BIN_PATH"
    rm -rf "sing-box-${LATEST_VERSION#v}-linux-${ARCH}" sing-box.tar.gz

    echo -e "\n${C_YELLOW}Step 3: Generating secrets and ports...${C_RESET}"; sudo mkdir -p "$WORK_DIR"
    local vless_port=$(shuf -i 20000-40000 -n 1); local hy2_port=$(shuf -i 40001-60000 -n 1); local tuic_port=$hy2_port; local nginx_port=$(shuf -i 10000-19999 -n 1)
    local uuid=$(sing-box generate uuid); local hy2_password=$(sing-box generate rand --base64 16)
    local reality_keys=$($SINGBOX_BIN_PATH generate reality-keypair); local private_key=$(echo "$reality_keys" | awk '/PrivateKey/ {print $2}' | tr -d '"'); local public_key=$(echo "$reality_keys" | awk '/PublicKey/ {print $2}' | tr -d '"')
    local sub_path=$(sing-box generate rand --hex 16)
    sudo openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "${WORK_DIR}/private.key" -out "${WORK_DIR}/cert.pem" -subj "/CN=localhost" -days 3650 &> /dev/null

    # --- NEW: Save all variables to a central file ---
    sudo bash -c "cat > $VARS_PATH" << EOF
VLESS_PORT=$vless_port
HY2_PORT=$hy2_port
TUIC_PORT=$tuic_port
NGINX_PORT=$nginx_port
UUID=$uuid
HY2_PASSWORD=$hy2_password
PUBLIC_KEY=$public_key
SUB_PATH=$sub_path
EOF

    echo -e "\n${C_YELLOW}Step 4: Building the Super-Config file...${C_RESET}"
    sudo bash -c "cat > $CONFIG_PATH" << EOF
{ "log": { "level": "warn" }, "dns":{ "servers": [ { "tag": "google", "address": "tls://8.8.8.8" } ]}, "inbounds": [ { "type": "vless", "tag": "vless-in", "listen": "::", "listen_port": $vless_port, "users": [ { "uuid": "$uuid", "flow": "xtls-rprx-vision" } ], "tls": { "enabled": true, "server_name": "www.microsoft.com", "reality": { "enabled": true, "handshake": { "server": "www.microsoft.com", "server_port": 443 }, "private_key": "$private_key", "short_id": "" } } }, { "type": "vmess", "tag": "vmess-ws-in", "listen": "127.0.0.1", "listen_port": 8001, "users": [ { "uuid": "$uuid" } ], "transport": { "type": "ws", "path": "/vmess-argo" } }, { "type": "hysteria2", "tag": "hysteria2-in", "listen": "::", "listen_port": $hy2_port, "users": [ { "password": "$hy2_password" } ], "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "${WORK_DIR}/cert.pem", "key_path": "${WORK_DIR}/private.key" } }, { "type": "tuic", "tag": "tuic-in", "listen": "::", "listen_port": $tuic_port, "users": [ { "uuid": "$uuid", "password": "$hy2_password" } ], "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "${WORK_DIR}/cert.pem", "key_path": "${WORK_DIR}/private.key" } } ], "outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" }, { "type": "wireguard", "tag": "warp-out", "server": "engage.cloudflareclient.com", "server_port": 2408, "local_address": ["172.16.0.2/32"], "private_key": "gBthRjevHDGyV0KvYwYE52NIPy29sSrVr6rcQtYNcXA=", "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=" } ], "route": { "rules": [ { "protocol": "dns", "outbound": "direct" }, { "geosite": ["openai", "netflix"], "outbound": "warp-out" } ] } }
EOF

    echo -e "\n${C_YELLOW}Step 5: Setting up services...${C_RESET}"
    sudo bash -c "cat > /etc/systemd/system/sing-box.service" << EOF
[Unit]\nDescription=sing-box service\nAfter=network.target\n[Service]\nUser=root\nWorkingDirectory=${WORK_DIR}\nExecStart=${SINGBOX_BIN_PATH} run -c ${CONFIG_PATH}\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target
EOF
    sudo bash -c "cat > /etc/systemd/system/argo.service" << EOF
[Unit]\nDescription=Cloudflare Argo Tunnel\nAfter=network.target\n[Service]\nExecStart=${CLOUDFLARED_BIN_PATH} tunnel --url http://localhost:8001 --no-autoupdate\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target
EOF
    sudo bash -c "cat > $NGINX_CONFIG_PATH" << EOF
user www-data; worker_processes auto; pid /run/nginx.pid; events { worker_connections 768; } http { server { listen $nginx_port; server_name _; location /$sub_path { alias ${SUBSCRIPTION_PATH}; } } }
EOF

    echo -e "\n${C_YELLOW}Step 6: Starting all services...${C_RESET}"
    sudo systemctl daemon-reload
    sudo systemctl enable --now sing-box argo nginx &> /dev/null

    sleep 5 # Give services time to start

    display_all_in_one_info

    echo -e "\n${C_B_GREEN}✅ All-in-One Super-Config installation is complete!${C_RESET}"
}

# --- NEW: Function now reads variables from the saved file ---
display_all_in_one_info() {
    if [ ! -f "$VARS_PATH" ]; then
        echo -e "\n${C_RED}Configuration variables not found. Please install the service first.${C_RESET}"; return
    fi
    source "$VARS_PATH" # Load all variables

    local server_ip=$(get_server_ip)
    local isp_info=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed 's/ /_/g' || echo "EKray")

    echo -e "\n${C_YELLOW}Fetching Argo Tunnel domain (please wait)...${C_RESET}"; local argo_domain
    for i in {1..5}; do
        argo_domain=$(sudo journalctl -u argo -n 10 --no-pager | grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' | head -n 1 | sed 's/https:\/\///')
        if [ -n "$argo_domain" ]; then break; fi; sleep 2
    done
    if [ -z "$argo_domain" ]; then echo -e "${C_RED}Could not fetch Argo domain. Check 'systemctl status argo'.${C_RESET}"; argo_domain="ARGO_DOMAIN_NOT_FOUND"; fi

    local vless_link="vless://${UUID}@${server_ip}:${VLESS_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUBLIC_KEY}&type=tcp#${isp_info}-Reality"
    local vmess_ws_link="vmess://$(echo "{\"v\":\"2\",\"ps\":\"${isp_info}-Argo\",\"add\":\"www.visa.com.tw\",\"port\":\"443\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/vmess-argo\",\"tls\":\"tls\",\"sni\":\"${argo_domain}\"}" | base64 -w0)"
    local hy2_link="hysteria2://${HY2_PASSWORD}@${server_ip}:${HY2_PORT}/?sni=localhost&insecure=1#${isp_info}-Hysteria2"
    local tuic_link="tuic://${UUID}:${HY2_PASSWORD}@${server_ip}:${TUIC_PORT}?sni=localhost&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${isp_info}-TUIC"

    local sub_content="${vless_link}\n${vmess_ws_link}\n${hy2_link}\n${tuic_link}"
    echo -e "$sub_content" | sudo tee "${WORK_DIR}/url.txt" > /dev/null
    echo -e "$sub_content" | base64 -w0 | sudo tee "$SUBSCRIPTION_PATH" > /dev/null
    local sub_link="http://${server_ip}:${NGINX_PORT}/${SUB_PATH}"

    clear; print_header "✅ Installation Complete!"
    echo -e "Here are your connection details:\n"
    echo -e "${C_CYAN}--- VLESS + Reality ---${C_RESET}"; echo "$vless_link"
    echo -e "${C_CYAN}--- VMess + WebSocket (Argo) ---${C_RESET}"; echo "$vmess_ws_link"
    echo -e "${C_CYAN}--- Hysteria2 ---${C_RESET}"; echo "$hy2_link"
    echo -e "${C_CYAN}--- TUICv5 ---${C_RESET}"; echo "$tuic_link"
    echo -e "\n-----------------------------------------------"
    echo -e "${C_B_GREEN}⭐ Subscription Link (copy this into your client):${C_RESET}"
    echo -e "${C_YELLOW}$sub_link${C_RESET}"
    echo -e "\n${C_B_GREEN}📱 Or scan the QR Code:${C_RESET}"; qrencode -t UTF8 -m 1 "$sub_link"
    echo "==============================================="
}

uninstall_ekray() {
    echo -e "\n${C_RED}WARNING: This will REMOVE ALL EKray files & services.${C_RESET}"; read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        sudo systemctl stop sing-box argo nginx &> /dev/null; sudo systemctl disable sing-box argo nginx &> /dev/null
        sudo rm -f /etc/systemd/system/{sing-box,argo,nginx}.service
        sudo rm -f "$SINGBOX_BIN_PATH" "$CLOUDFLARED_BIN_PATH"; sudo rm -rf "$WORK_DIR"
        manage_packages uninstall nginx
        sudo systemctl daemon-reload
        echo -e "\n${C_B_GREEN}EKray has been completely uninstalled.${C_RESET}"
    else
        echo -e "\n${C_YELLOW}Uninstall cancelled.${C_RESET}"
    fi
}

#=================================================
# SCRIPT EXECUTION STARTS HERE
#=================================================

main_menu() {
    while true; do
        clear; print_header "🚀 EKray Panel v3.0.1 🚀"
        echo -e "   ${C_CYAN}by Edward & Kaveh${C_RESET}\n"
        echo -e "  ${C_YELLOW}1)${C_RESET} 🚀 Install All-in-One Super-Config"
        echo -e "  ${C_YELLOW}2)${C_RESET} ℹ️  View Connection Info"
        echo -e "  ${C_YELLOW}3)${C_RESET} ⚙️  Service Control (Coming Soon)"
        echo -e "  ${C_RED}4)${C_RESET} 🗑️ Uninstall Everything"
        echo -e "  ${C_RED}5)${C_RESET} 🚪 Exit"
        echo "-----------------------------------------------"
        read -p "Enter your choice [1-5]: " choice
        case $choice in
            1) install_all_in_one; press_any_key ;;
            2) display_all_in_one_info; press_any_key ;;
            3) echo -e "\n${C_MAGENTA}This feature will be added soon.${C_RESET}"; press_any_key ;;
            4) uninstall_ekray; press_any_key ;;
            5) echo -e "\n${C_BLUE}Goodbye!${C_RESET}"; exit 0 ;;
            *) echo -e "\n${C_RED}Invalid option.${C_RESET}"; sleep 2 ;;
        esac
    done
}

check_dependencies
main_menu

