#!/bin/bash

# =================================================================
# EKray - Smart Management Script
# Version: 1.9.1-beta (Style & Color Refactor)
# Author: Kaveh & Edward
# GitHub: https://github.com/edwardium/EKray.git
# =================================================================

# --- Style & Color Definitions ---
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_B_GREEN='\033[1;32m'

# --- Paths (unchanged) ---
CONFIG_PATH="/etc/sing-box/config.json"
SINGBOX_BIN_PATH="/usr/local/bin/sing-box"
SERVICE_PATH="/etc/systemd/system/sing-box.service"

# --- Helper Functions ---
press_any_key() { echo ""; read -n 1 -s -r -p "Press any key to return..."; }
print_header() {
    local title="$1"
    local title_len=${#title}
    local padding_len=$(( (45 - title_len) / 2 ))
    printf "\n${C_B_GREEN}┌─────────────────────────────────────────────┐${C_RESET}\n"
    printf "${C_B_GREEN}│%*s%s%*s│${C_RESET}\n" "$padding_len" "" "$title" "$((45 - title_len - padding_len))" ""
    printf "${C_B_GREEN}└─────────────────────────────────────────────┘${C_RESET}\n"
}

#=================================================
# NEW MENU STRUCTURE
#=================================================

# --- Main Menu ---
main_menu() {
    while true; do
        clear
        print_header "🚀 EKray Panel v1.9.1 🚀"
        echo -e "   ${C_CYAN}by Edward & Kaveh${C_RESET}"
        echo ""
        echo -e "  ${C_YELLOW}1)${C_RESET} 📦 Installation & Core Management"
        echo -e "  ${C_YELLOW}2)${C_RESET} 👥 Protocol & User Management"
        echo -e "  ${C_YELLOW}3)${C_RESET} ⚙️  Service & System Control"
        echo -e "  ${C_YELLOW}4)${C_RESET} 🛠️  Advanced Tools ${C_MAGENTA}(Coming Soon)${C_RESET}"
        echo -e "  ${C_RED}5)${C_RESET} 🚪 Exit"
        echo "-----------------------------------------------"
        read -p "Enter your choice [1-5]: " choice
        case $choice in
            1) installation_menu ;;
            2) protocol_user_menu ;;
            3) service_control_menu ;;
            4) echo -e "\n${C_MAGENTA}Advanced tools will be added in future versions.${C_RESET}"; press_any_key ;;
            5) echo -e "\n${C_BLUE}Goodbye!${C_RESET}"; exit 0 ;;
            *) echo -e "\n${C_RED}Invalid option.${C_RESET}"; sleep 2 ;;
        esac
    done
}

# --- 1. Installation Menu ---
installation_menu() {
    clear
    print_header "📦 Installation & Core"
    echo -e "  ${C_GREEN}1)${C_RESET} 🔄 Update Server & Dependencies"
    echo -e "  ${C_GREEN}2)${C_RESET} 📥 Install sing-box Core"
    echo -e "  ${C_RED}3)${C_RESET} 🗑️ Uninstall sing-box Core"
    echo -e "  ${C_YELLOW}4)${C_RESET} ↩️ Back to Main Menu"
    echo "-----------------------------------------------"
    read -p "Enter your choice [1-4]: " choice
    case $choice in
        1) update_server ;;
        2) install_singbox ;;
        3) uninstall_ekray ;;
        4) return ;;
        *) echo -e "\n${C_RED}Invalid option.${C_RESET}"; sleep 2 ;;
    esac
    press_any_key
}

# --- 2. Protocol & User Menu ---
protocol_user_menu() {
    clear
    print_header "👥 Protocol & User Management"
    echo -e "  ${C_GREEN}1)${C_RESET} ➕ Install New Protocol"
    echo -e "  ${C_GREEN}2)${C_RESET} 📇 Manage Existing Users"
    echo -e "  ${C_RED}3)${C_RESET} 🔥 Delete All Protocols & Users"
    echo -e "  ${C_YELLOW}4)${C_RESET} ↩️ Back to Main Menu"
    echo "-----------------------------------------------"
    read -p "Enter your choice [1-4]: " choice
    case $choice in
        1) install_protocol_menu ;;
        2) list_and_manage_users ;;
        3) delete_all_service_configs ;;
        4) return ;;
        *) echo -e "\n${C_RED}Invalid option.${C_RESET}"; sleep 2 ;;
    esac
}

# --- 3. Service & System Control Menu ---
service_control_menu() {
    clear
    print_header "⚙️ Service & System Control"
    echo -e "  ${C_GREEN}1)${C_RESET} ▶️ Start sing-box Service"
    echo -e "  ${C_RED}2)${C_RESET} ⏹️ Stop sing-box Service"
    echo -e "  ${C_YELLOW}3)${C_RESET} 🔄 Restart sing-box Service"
    echo -e "  ${C_GREEN}4)${C_RESET} 🔒 Enable Service on Boot"
    echo -e "  ${C_RED}5)${C_RESET} 🔓 Disable Service on Boot"
    echo "-----------------------------------------------"
    echo -e "  ${C_CYAN}6)${C_RESET} 🩺 System Status Check"
    echo -e "  ${C_CYAN}7)${C_RESET} 📜 View Service Logs"
    echo -e "  ${C_CYAN}8)${C_RESET} ✅ Validate Config File"
    echo "-----------------------------------------------"
    echo -e "  ${C_YELLOW}9)${C_RESET} ↩️ Back to Main Menu"
    read -p "Enter your choice [1-9]: " choice
    case $choice in
        1) sudo systemctl start sing-box; echo -e "\n${C_GREEN}Start command sent.${C_RESET}" ;;
        2) sudo systemctl stop sing-box; echo -e "\n${C_GREEN}Stop command sent.${C_RESET}" ;;
        3) sudo systemctl restart sing-box; echo -e "\n${C_GREEN}Restart command sent.${C_RESET}" ;;
        4) sudo systemctl enable sing-box &> /dev/null; echo -e "\n${C_GREEN}Autostart enabled.${C_RESET}" ;;
        5) sudo systemctl disable sing-box &> /dev/null; echo -e "\n${C_GREEN}Autostart disabled.${C_RESET}" ;;
        6) system_status_check ;;
        7) view_service_logs ;;
        8) validate_config_file ;;
        9) return ;;
        *) echo -e "\n${C_RED}Invalid option.${C_RESET}"; sleep 2 ;;
    esac
    press_any_key
}


#=================================================
# FUNCTION IMPLEMENTATIONS (Logic is the same, only echo colors changed)
#=================================================

# For brevity, only showing a few functions here.
# The full, styled script is in the immersive block.

update_server() {
    echo -e "\n${C_YELLOW}Updating server... This may take a while.${C_RESET}"
    if sudo apt-get update && sudo apt-get upgrade -y; then
        echo -e "${C_B_GREEN}Server updated successfully!${C_RESET}"
    else
        echo -e "${C_RED}An error occurred during the update.${C_RESET}"
    fi
}

install_singbox() {
    if command -v sing-box &> /dev/null; then
        echo -e "\n${C_GREEN}sing-box is already installed.${C_RESET}"; return;
    fi
    echo -e "\n${C_YELLOW}Installing sing-box...${C_RESET}"
    # ... (rest of the install logic)
}

# --- Main application loop ---
check_dependencies
main_menu
