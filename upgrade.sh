#!/bin/bash
# +----------------------------------------------------------------------------+
# |     upgrade.sh - A script to help upgrade from Debian 12 to Debian 13.     |
# +----------------------------------------------------------------------------+
set -e

version_check() {
    if [ ! -f /etc/debian_version ]; then
        echo "+------------------------------------------------------------------------------+"
        echo "| Error: This script is designed to run within Debian-based environments. Your |"
        echo "|   environment appears to be missing information needed to validate that this |"
        echo "|   installation is compatible with the ds-update.sh script.                   |"
        echo "|                                                                              |"
        echo "| This error is based on information read from the /etc/debian_version file.   |"
        echo "+------------------------------------------------------------------------------+"
        exit 1
    fi
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d'.' -f1)
    if [ "$DEBIAN_VERSION" -lt 12 ]; then
        echo "+------------------------------------------------------------------------------+"
        echo "| Error: This script requires an environment running Debian version 12 or      |"
        echo "|   higher. You appear to be running a version older than 12 (Bookworm).       |"
        echo "|                                                                              |"
        echo "| This error is based on information read from the /etc/debian_version file.   |"
        echo "+------------------------------------------------------------------------------+"
        exit 1
    fi
}

sudo_check() {
    if ! command -v sudo &> /dev/null; then
        if [[ $EUID -ne 0 ]]; then
            echo "+------------------------------------------------------------------------------+"
            echo "|     Error: This script must be run as root or with superuser privileges.     |"
            echo "+------------------------------------------------------------------------------+"
            exit 1
        fi
        echo " "
        echo " The sudo package is used by this script and will now be installed..."
        echo " "
        sleep 1
        apt update && apt install -y sudo
    fi
}

gum_check() {
    if ! command -v gum &> /dev/null; then
        echo " "
        echo " Gum from Charm is used by this script and will now be installed..."
        echo " "
        sleep 1
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
        sudo apt update && apt install -y gum
    fi
}

# Check for pre-requisites and install them if needed
version_check
sudo_check
gum_check

# Prompt to set the default locale for Debian along with the Environment Timezone (needed for some new image configs)
if gum confirm "Do you want to set the locale and timezone for this environment?"; then
    gum style --foreground 57 --padding "1 1" "Running Configuration Utility to set Environment Locale..."
    sleep 1
    sudo dpkg-reconfigure locales
    gum style --foreground 57 --padding "1 1" "Running Configuration Utility to set Environment Timezone..."
    sleep 1
    sudo dpkg-reconfigure tzdata
    gum style --foreground 212 --padding "1 1" "Environment Locale and Timezone have been set and updated."
fi

# On Bookworm, run a complete upgrade after updating the apt sources; on Trixie, modernize existing sources post-upgrade
# and replace select packages with modern versions (such as replacing "neofetch" with "fastfetch" post-upgrade)
if [ "$DEBIAN_VERSION" -lt 13 ]; then
    # Run a set of package upgrades pre-update
    gum style --foreground 57 --padding "1 1" "Running a full apt upgrade and package cleanup..."
    sleep 1
    sudo apt update
    sudo apt install --fix-missing
    sudo apt upgrade --allow-downgrades
    sudo apt full-upgrade --allow-downgrades -V
    sudo apt install -f
    sudo apt autoremove --purge
    sudo apt autoclean
    sudo apt clean
    gum style --foreground 212 --padding "1 1" "Packages have been updated and cleanup tools have completed."
    gum style --foreground 57 --padding "1 1" "Updating the apt sources from Bookworm to Trixie..."
    sleep 1
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.old
    sudo cp -R /etc/apt/sources.list.d/ /etc/apt/sources.list.d.old
    if command -v neofetch >&2; then
        gum style --foreground 57 --padding "1 1" "Uninstalling neofetch..."
        sleep 1
        sudo apt purge -y neofetch
        gum style --foreground 212 --padding "1 1" "Neofetch has been removed from your environment."
    fi
    if command -v fastfetch >&2; then
        gum style --foreground 57 --padding "1 1" "Uninstalling fastfetch..."
        sleep 1
        sudo apt purge -y fastfetch
        gum style --foreground 212 --padding "1 1" "Fastfetch has been removed from your environment."
    fi
    if command -v gping >&2; then
        gum style --foreground 57 --padding "1 1" "Uninstalling gping..."
        sleep 1
        sudo apt purge -y gping
        if [ -f /usr/share/keyrings/azlux.gpg ]; then
            rm /usr/share/keyrings/azlux.gpg
        fi
        if [ -f  /etc/apt/sources.list.d/azlux.list ]; then
            rm  /etc/apt/sources.list.d/azlux.list
        fi
        gum style --foreground 212 --padding "1 1" "Gping has been removed from your environment."
    fi
    sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
    SOURCESDIR="/etc/apt/sources.list.d"
    if [ -d "$SOURCESDIR" ]; then
        find "$SOURCESDIR" -type f -exec sudo sed -i 's/bookworm/trixie/g' {} +
    fi
    gum style --foreground 212 --padding "1 1" "The apt source list updates have completed."
    gum style --foreground 57 --padding "1 1" "Checking for apt policy issues..."
    sudo apt policy
    sleep 2
    gum style --foreground 57 --padding "1 1" "Running a full apt upgrade with the new sources..."
    sleep 1
    sudo apt update
    sudo apt dist-upgrade
else
    gum style --foreground 57 --padding "1 1" "Modernizing the existing apt sources to the new format..."
    sleep 1
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sudo cp -R /etc/apt/sources.list.d/ /etc/apt/sources.list.d.bak
    sudo apt modernize-sources
    gum style --foreground 212 --padding "1 1" "The apt sources have been modernized."
    if command -v neofetch >&2; then
        gum style --foreground 57 --padding "1 1" "Replacing neofetch with fastfetch..."
        sleep 1
        sudo apt purge -y neofetch
        sudo apt install -y fastfetch
        gum style --foreground 212 --padding "1 1" "Fastfetch has been installed to update the outdated neofetch package."
    fi
    if ! command -v fastfetch &> /dev/null; then
        gum style --foreground 57 --padding "1 1" "Installing fastfetch..."
        sleep 1
        sudo apt install -y fastfetch
        gum style --foreground 212 --padding "1 1" "Fastfetch has been installed within your environment."
    fi
    if ! command -v gping &> /dev/null; then
        gum style --foreground 57 --padding "1 1" "Installing gping..."
        sleep 1
        sudo apt install -y gping
        gum style --foreground 212 --padding "1 1" "Gping has been installed within your environment."
    fi

# Run a full set of package upgrades along with a package cleanup post-update
    gum style --foreground 57 --padding "1 1" "Running a full apt upgrade and package cleanup..."
    sleep 1
    sudo apt update
    sudo apt install --fix-missing
    sudo apt upgrade --allow-downgrades
    sudo apt full-upgrade --allow-downgrades -V
    sudo apt install -f
    sudo apt autoremove --purge
    sudo apt autoclean
    sudo apt clean
    gum style --foreground 212 --padding "1 1" "Packages have been updated and cleanup tools have completed."
fi

# Prompt for a reboot before wrapping up and exiting cleanly
if gum confirm "Do you want to reboot this environment?"; then
    gum style --border double --foreground 212 --border-foreground 57 --margin "1" --padding "1 2" "The dt-trixie.sh script has completed successfully, rebooting..."
    sleep 1
    sudo systemctl reboot
else
    gum style --border double --foreground 212 --border-foreground 57 --margin "1" --padding "1 2" "The dt-trixie.sh script has completed successfully."
fi
exit 0