#!/bin/bash
# +----------------------------------------------------------------------------+
# |        update.sh - A script to update Debian 12 or 13 environments.        |
# +----------------------------------------------------------------------------+
set -euo pipefail

service_status() {
    if gum confirm "Do you want to view the status of currently running services?"; then
        gum style --foreground 212 --padding "1 1" "Displaying all currently configured services..."
        $USE_SUDO service --status-all
        echo " "
        read -p " Press [Enter] to continue..."
    fi
}

packages_status() {
    gum style --foreground 57 --padding "1 1" "Updating local package lists..."
    $USE_SUDO apt update
    gum style --foreground 212 --padding "1 1" "Local package lists have been updated."
    if gum confirm "Do you want to review the list of packages need updates?"; then
        gum style --foreground 212 --padding "1 1" "Displaying packages with pending updates..."
        $USE_SUDO apt list --upgradable
        echo " "
        read -p " Press [Enter] to continue..."
    fi
}

apt_coreupdate() {
    gum style --foreground 57 --padding "1 1" "Updating installed packages..."
    sleep 1
    $USE_SUDO apt upgrade -y
    gum style --foreground 212 --padding "1 1" "Installed packages have been updated."
    if command -v npm &> /dev/null; then
        gum style --foreground 57 --padding "1 1" "Updating global npm packages..."
        sleep 1
        $USE_SUDO npm update -g
        gum style --foreground 212 --padding "1 1" "Global npm packages have been updated."
    fi
}

apt_askfullupdate() {
if gum confirm "Do you want to run a full apt upgrade along with a set package cleanup tools?"; then
    gum style --foreground 57 --padding "1 1" "Running a full apt upgrade and package cleanup..."
    $USE_SUDO apt update
    $USE_SUDO apt install --fix-missing
    $USE_SUDO apt upgrade --allow-downgrades
    $USE_SUDO apt full-upgrade --allow-downgrades -V
    $USE_SUDO apt install -f
    $USE_SUDO apt autoremove --purge
    $USE_SUDO apt autoclean
    $USE_SUDO apt clean
    gum style --foreground 212 --padding "1 1" "Packages have been updated and cleanup tools have completed."
fi
}

postupdate_status() {
    if command -v duf >&2; then
        gum style --foreground 57 --padding "1 1" "Querying current status of storage devices..."
    else
        gum style --foreground 57 --padding "1 1" "Duf utility not found, installing from apt repositories..."
        sleep 1
        $USE_SUDO apt install -y duf
        gum style --foreground 57 --padding "1 1" "Querying current status of storage devices..."
    fi
    sleep 1
    duf -hide special
    gum style --foreground 57 --padding "1 1" "Checking if a restart or reboot is recommended..."
    sleep 1
    $USE_SUDO /sbin/needrestart
    gum style --foreground 212 --padding "1 1" "Packages have been updated and cleanup tools have completed."
}

COMMON_SH_PATH=""
if [ -f "./common.sh" ]; then
    COMMON_SH_PATH="./common.sh"
elif [ -f "$HOME/debian-scripts/common.sh" ]; then
    COMMON_SH_PATH="$HOME/debian-scripts/common.sh"
elif [ -f "$HOME/scripts/common.sh" ]; then
    COMMON_SH_PATH="$HOME/scripts/common.sh"
elif [ -f "$HOME/Scripts/common.sh" ]; then
    COMMON_SH_PATH="$HOME/scripts/common.sh"
else
    echo " Error: common.sh not found in ./, ~/debian-scripts/, ~/scripts/, or ~/Scripts/."
    exit 1
fi

source "$COMMON_SH_PATH"
version_check
sudo_check
deps_check
gum_check
clear
$USE_SUDO echo ""
uptime
echo ""
fastfetch_setup
fastfetch
echo ""
read -p " If you are ready to proceed, press [Enter] to start the script..."
echo ""
service_status
packages_status
apt_coreupdate
apt_askfullupdate
postupdate_status
complete_script
exit 0