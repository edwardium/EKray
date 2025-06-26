#!/bin/bash

# =================================================================
# MKray - Smart Management Script
# Version: 0.1 (The Skeleton)
# Author: Kaveh & Edward
# GitHub: https://github.com/YourUsername/MKray
# =================================================================

# --- رنگ‌ها برای خروجی ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- تابع برای آپدیت سرور ---
update_server() {
    echo -e "${YELLOW}در حال شروع آپدیت سرور...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    echo -e "${GREEN}سرور با موفقیت آپدیت شد!${NC}"
    read -n 1 -s -r -p "برای بازگشت به منوی اصلی، یک کلید را فشار دهید..."
}

# --- تابع نمایش منوی اصلی ---
show_main_menu() {
    clear
    echo "============================================="
    echo "        پنل مدیریت MKray v0.1          "
    echo "============================================="
    echo "لطفا یک گزینه را انتخاب کنید:"
    echo ""
    echo -e "  ${GREEN}1)${NC} آپدیت سرور و پیش‌نیازها"
    echo -e "  ${YELLOW}2)${NC} نصب و مدیریت سرویس‌ها (به زودی)"
    echo -e "  ${RED}3)${NC} خروج"
    echo ""
    echo "---------------------------------------------"
}

# --- حلقه اصلی برنامه ---
while true; do
    show_main_menu
    read -p "گزینه خود را وارد کنید [1-3]: " choice

    case $choice in
        1)
            update_server
            ;;
        2)
            echo -e "${YELLOW}این قابلیت در نسخه‌های بعدی اضافه خواهد شد.${NC}"
            sleep 2
            ;;
        3)
            echo "خروج از برنامه..."
            exit 0
            ;;
        *)
            echo -e "${RED}گزینه نامعتبر است. لطفا دوباره تلاش کنید.${NC}"
            sleep 2
            ;;
    esac
done