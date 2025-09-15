#!/bin/bash
# +----------------------------------------------------------------------------+
# |    secure.sh - A script to help harden and secure a Debian environment.    |
# +----------------------------------------------------------------------------+
set -euo pipefail

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
connection_check
version_check
sudo_check
deps_check
gum_check
localetime_setup
fastfetch_setup
gum style --foreground 57 --padding "1 1" "Choose security practices or actions to implement:"
readarray -t ENV_OPTIONS < <(gum choose --no-limit \
    "Configure SSH" \
    "Install and Configure UFW" \
    "Install and Configure Fail2ban" \
    "Setup and Configure Unattended Upgrades" \
    "Update and Upgrade Installed Packages")
for OPTION in "${ENV_OPTIONS[@]}"; do
    case $OPTION in
        "Configure SSH")
            ssh_setup
            ;;
        "Install and Configure UFW")
            firewall_setup
            ;;
        "Install and Configure Fail2ban")
            fail2ban_setup
            ;;
        "Setup and Configure Unattended Upgrades")
            unattended_setup
            ;;
        "Update and Upgrade Installed Packages")
            apt_fullupdate
            ;;

        *)
            gum style --foreground 57 --padding "1 1" "No practices or actions selected, skipping..."
            sleep 1
            ;;
    esac
done
complete_script
exit 0