#!/bin/bash
# +----------------------------------------------------------------------------+
# |        update.sh - A script to update Debian 12 or 13 environments.        |
# +----------------------------------------------------------------------------+
set -euo pipefail

connection_check() {
    ping -c 1 8.8.8.8 &> /dev/null || { echo " Error: No internet connection."; exit 1; }
}

version_check() {
    if [ ! -f /etc/debian_version ]; then
        echo " Error: This script is designed to run within Debian-based environments. Your"
        echo "   environment appears to be missing information needed to validate that this"
        echo "   environment is compatible with this script."
        echo ""
        echo " This error is based on information read from the /etc/debian_version file."
        exit 1
    fi
    DEBIAN_VERSION_ETC=$(cat /etc/debian_version)
    DEBIAN_VERSION=$(echo "$DEBIAN_VERSION_ETC" | sed -n 's/^\([0-9]\+\).*/\1/p')
    if ! [[ "$DEBIAN_VERSION" =~ ^[0-9]+$ ]] || [ "$DEBIAN_VERSION" -lt 12 ]; then
        echo " Error: This script requires an environment running Debian version 12 or"
        echo "   higher. Detected version: $DEBIAN_VERSION_ETC (parsed as $DEBIAN_VERSION)."
        echo ""
        echo " This error is based on information read from the /etc/debian_version file."
        exit 1
    fi
}

sudo_check() {
    if ! command -v sudo &> /dev/null; then
        if [[ $EUID -ne 0 ]]; then
            echo " Error: This script must be run as root or with superuser privileges."
            exit 1
        fi
        echo ""
        echo " Info: the sudo package is used by this script and will now be installed..."
        echo ""
        sleep 1
        apt update && apt install -y sudo
    fi
    if [[ $EUID -eq 0 ]]; then
        USE_SUDO=""
    else
        USE_SUDO="sudo"
    fi
}

deps_check() {
    local missing_deps=()
    for dep in curl wget gpg jq; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo ""
        echo " Info: The following utilities are required and will now be installed: ${missing_deps[*]}"
        echo ""
        sleep 1
        if ! { $USE_SUDO apt update && $USE_SUDO apt install -y "${missing_deps[@]}"; }; then
            echo " Error: Failed to install required utilities: ${missing_deps[*]}"
            exit 1
        fi
    fi
}

gum_check() {
    if ! command -v gum &> /dev/null; then
        echo ""
        echo " Info: gum from Charm is used by this script and will now be installed..."
        echo ""
        sleep 1
        $USE_SUDO mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | $USE_SUDO gpg --dearmor -o /etc/apt/keyrings/charm.gpg
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $USE_SUDO tee /etc/apt/sources.list.d/charm.list
        $USE_SUDO apt update && $USE_SUDO apt install -y gum
    fi
}

fastfetch_setup() {
    if command -v neofetch >&2; then
        gum style --foreground 57 --padding "1 1" "Removing deprecated neofetch..."
        sleep 1
        $USE_SUDO apt purge -y neofetch
        gum style --foreground 212 --padding "1 1" "The neofetch package has been removed."
    fi
    if command -v jq &> /dev/null; then
        FASTFETCH_NEW_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')
    else
        FASTFETCH_NEW_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep -o '"tag_name"' | head -1 | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    fi
    if [ -z "$FASTFETCH_NEW_VERSION" ]; then
        echo " Error: Could not retrieve fastfetch version from GitHub repository."
        exit 1
    fi
    if command -v fastfetch &> /dev/null; then
        FASTFETCH_INSTALLED_VERSION=$(fastfetch --version 2>/dev/null | sed -n 's/fastfetch \([^ ]*\).*/\1/p' || echo "unknown")
        if [ "$FASTFETCH_INSTALLED_VERSION" = "$FASTFETCH_NEW_VERSION" ]; then
            return
        else
            gum style --foreground 57 --padding "1 1" "Uninstalling existing fastfetch version $FASTFETCH_INSTALLED_VERSION..."
            if $USE_SUDO apt remove -y fastfetch 2>/dev/null; then
                echo ""
                echo " Info: fastfetch $FASTFETCH_INSTALLED_VERSION uninstalled via apt."
                echo ""
            elif $USE_SUDO dpkg -r fastfetch 2>/dev/null; then
                echo ""
                echo " Info: fastfetch $FASTFETCH_INSTALLED_VERSION uninstalled via dpkg."
                echo ""
            else
                echo " Warning: Could not uninstall existing fastfetch $FASTFETCH_INSTALLED_VERSION. Proceeding with install."
            fi
            if command -v fastfetch &> /dev/null; then
                echo ""
                echo " Error: fastfetch $FASTFETCH_INSTALLED_VERSION still detected after uninstall. Manual uninstallation may be needed."
                echo ""
                exit 1
            fi
        fi
    fi
    if ! command -v fastfetch &> /dev/null; then
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            arm64) ARCH="arm64" ;;
            armv7l) ARCH="armv7l" ;;
            armv6l) ARCH="armv6l" ;;
            ppc64le) ARCH="ppc64le" ;;
            riscv64) ARCH="riscv64" ;;
            s390x) ARCH="s390x" ;;
            *) echo " Unsupported architecture detected: $ARCH"; exit 1 ;;
        esac
        FASTFETCH_DEB="fastfetch-linux-${ARCH}.deb"
        FASTFETCH_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_NEW_VERSION}/${FASTFETCH_DEB}"
        FASTFETCH_CHECKSUM_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_NEW_VERSION}/fastfetch-linux.sha256"
        FASTFETCH_DEB_TEMP=$(mktemp /tmp/fastfetch-XXXXXX.deb)
        if ! wget -q "$FASTFETCH_URL" -O "$FASTFETCH_DEB_TEMP"; then
            echo " Error: Failed to download fastfetch from $FASTFETCH_URL"
            rm -f "$FASTFETCH_DEB_TEMP"
            exit 1
        fi
        EXPECTED_CHECKSUM=$(curl -s "$FASTFETCH_CHECKSUM_URL" | grep "$FASTFETCH_DEB" | awk '{print $1}')
        if [ -z "$EXPECTED_CHECKSUM" ]; then
            echo " Error: Could not retrieve checksum for fastfetch"
            rm -f "$FASTFETCH_DEB_TEMP"
            exit 1
        fi
        ACTUAL_CHECKSUM=$(sha256sum "$FASTFETCH_DEB_TEMP" | awk '{print $1}')
        if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
            echo " Error: Checksum verification failed for fastfetch"
            rm -f "$FASTFETCH_DEB_TEMP"
            exit 1
        fi
        if ! $USE_SUDO dpkg -i "$FASTFETCH_DEB_TEMP"; then
            echo " Error: Failed to install fastfetch"
            rm -f "$FASTFETCH_DEB_TEMP"
            exit 1
        fi
        rm -f "$FASTFETCH_DEB_TEMP"
        gum style --foreground 212 --padding "1 1" "Fastfetch $FASTFETCH_NEW_VERSION has been installed."
        
    fi
}

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

apt_fullupdate() {
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

complete_script() {
    if gum confirm "Do you want to reboot this environment?"; then
        gum style --border double --foreground 212 --border-foreground 57 --margin "1" --padding "1 2" "The script has completed successfully, rebooting..."
        sleep 1
        $USE_SUDO systemctl reboot
    else
        gum style --border double --foreground 212 --border-foreground 57 --margin "1" --padding "1 2" "The script has completed successfully."
    fi
}

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
apt_fullupdate
postupdate_status
complete_script
exit 0