#!/bin/bash
# +----------------------------------------------------------------------------+
# |    prompt.sh - A simple script to setup the Starship prompt for a user.    |
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
    for dep in curl wget gpg; do
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
        gum style --foreground 57 --padding "1 1" "Removing depreciated neofetch..."
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

starship_setup() {
    gum style --foreground 57 --padding "1 1" "Checking that starship is already installed..."
    if ! command -v starship &> /dev/null; then
        curl -sS https://starship.rs/install.sh | sh
    fi
    gum style --foreground 57 --padding "1 1" "Adding starship to the bash shell..."
    if ! grep -q "eval \"\$(starship init bash)\"" "$HOME/.bashrc"; then
        echo "eval \"\$(starship init bash)\"" >> "$HOME/.bashrc"
    fi
}

starship_config() {
    gum style --foreground 57 --padding "1 1" "Installing the plain text prompt presets..."
    if [ ! -d "$HOME/.config" ]; then
        mkdir -p "$HOME/.config"
    fi
    touch "$HOME/.config/starship.toml"
    starship preset plain-text-symbols -o "$HOME/.config/starship.toml"
    if command -v fastfetch &> /dev/null; then
        FASTFETCH_BLOCK='uptime; echo ""; if command -v fastfetch &> /dev/null; then fastfetch; fi; echo ""; df -h'
        if ! grep -Fxq "$FASTFETCH_BLOCK" "$HOME/.bashrc"; then
            echo "$FASTFETCH_BLOCK" >> "$HOME/.bashrc"
        fi
    fi
    gum style --foreground 212 --padding "1 1" " Info: starship has been configured and will be available on your next login."
}

connection_check
version_check
sudo_check
deps_check
gum_check
fastfetch_setup
cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%s)"
starship_setup
starship_config
exit 0