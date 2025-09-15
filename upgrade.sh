#!/bin/bash
# +----------------------------------------------------------------------------+
# |     upgrade.sh - A script to help upgrade from Debian 12 to Debian 13.     |
# +----------------------------------------------------------------------------+
set -euo pipefail

debian_upgrade() {
    if [ "$DEBIAN_VERSION" -lt 13 ]; then
        apt_fullupdate
        gum style --foreground 57 --padding "1 1" "Updating the apt sources from Bookworm to Trixie..."
        sleep 1
        $USE_SUDO cp /etc/apt/sources.list /etc/apt/sources.list.old
        $USE_SUDO cp -R /etc/apt/sources.list.d/ /etc/apt/sources.list.d.old
        if command -v neofetch >&2; then
            gum style --foreground 57 --padding "1 1" "Removing depreciated neofetch..."
            sleep 1
            $USE_SUDO apt purge -y neofetch
            gum style --foreground 212 --padding "1 1" "The neofetch package has been removed."
        fi
        if command -v fastfetch >&2; then
            gum style --foreground 57 --padding "1 1" "Removing fastfetch (will be reinstalled from GitHub)..."
            sleep 1
            $USE_SUDO apt purge -y fastfetch
            gum style --foreground 212 --padding "1 1" "The fastfetch package has been removed."
        fi
        if command -v gping >&2; then
            gum style --foreground 57 --padding "1 1" "Removing gping (will be reinstalled)..."
            sleep 1
            $USE_SUDO apt purge -y gping
            if [ -f /usr/share/keyrings/azlux.gpg ]; then
                $USE_SUDO rm /usr/share/keyrings/azlux.gpg
            fi
            if [ -f  /etc/apt/sources.list.d/azlux.list ]; then
                $USE_SUDO rm /etc/apt/sources.list.d/azlux.list
            fi
            gum style --foreground 212 --padding "1 1" "The gping package has been removed."
        fi
        $USE_SUDO sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
        $USE_SUDO sed -i 's/oldstable/stable/g' /etc/apt/sources.list
        SOURCESDIR="/etc/apt/sources.list.d"
        if [ -d "$SOURCESDIR" ]; then
            find "$SOURCESDIR" -type f -exec sudo sed -i 's/bookworm/trixie/g' {} +
        fi
        gum style --foreground 212 --padding "1 1" "The apt source list updates have completed."
        gum style --foreground 57 --padding "1 1" "Checking for apt policy issues..."
        $USE_SUDO apt policy
        sleep 2
        gum style --foreground 57 --padding "1 1" "Running a full apt upgrade with the new sources..."
        sleep 1
        $USE_SUDO apt update
        $USE_SUDO apt dist-upgrade
    else
        gum style --foreground 57 --padding "1 1" "Modernizing the existing apt sources to the new format..."
        sleep 1
        $USE_SUDO cp /etc/apt/sources.list /etc/apt/sources.list.bak
        $USE_SUDO cp -R /etc/apt/sources.list.d/ /etc/apt/sources.list.d.bak
        $USE_SUDO apt modernize-sources
        gum style --foreground 212 --padding "1 1" "The apt sources have been modernized."
        fastfetch_setup
        if ! command -v gping &> /dev/null; then
            gum style --foreground 57 --padding "1 1" "Installing gping..."
            sleep 1
            $USE_SUDO apt install -y gping
            gum style --foreground 212 --padding "1 1" "The gping package has been installed."
        fi
        apt_fullupdate
    fi
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
connection_check
version_check
sudo_check
deps_check
gum_check
localetime_setup
debian_upgrade
complete_script
exit 0