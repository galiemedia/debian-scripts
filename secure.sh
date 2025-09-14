#!/bin/bash
# +----------------------------------------------------------------------------+
# |    secure.sh - A script to help harden and secure a Debian environment.    |
# +----------------------------------------------------------------------------+
set -euo pipefail

source ./common.sh
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