#!/bin/bash
# +----------------------------------------------------------------------------+
# |    common.sh - A shared script with common functions for debian-scripts    |
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
            aarch64) ARCH="aarch64" ;;
            armv7l) ARCH="armv7l" ;;
            armv6l) ARCH="armv6l" ;;
            ppc64le) ARCH="ppc64le" ;;
            riscv64) ARCH="riscv64" ;;
            s390x) ARCH="s390x" ;;
            *) echo " Unsupported architecture detected: $ARCH"; exit 1 ;;
        esac
        FASTFETCH_DEB="fastfetch-linux-${ARCH}.deb"
        FASTFETCH_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_NEW_VERSION}/${FASTFETCH_DEB}"
        FASTFETCH_DEB_TEMP=$(mktemp /tmp/fastfetch-XXXXXX.deb)
        if ! wget -q "$FASTFETCH_URL" -O "$FASTFETCH_DEB_TEMP"; then
            echo " Error: Failed to download fastfetch from $FASTFETCH_URL"
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

localetime_setup() {
    if gum confirm "Do you want to set the locale and timezone for this environment?"; then
        gum style --foreground 57 --padding "1 1" "Running Configuration Utility to set Environment Locale..."
        sleep 1
        $USE_SUDO dpkg-reconfigure locales
        gum style --foreground 57 --padding "1 1" "Running Configuration Utility to set Environment Timezone..."
        sleep 1
        $USE_SUDO dpkg-reconfigure tzdata
        gum style --foreground 212 --padding "1 1" "Environment Locale and Timezone have been set and updated."
    fi
}

ssh_setup() {
    gum style --foreground 57 --padding "1 1" "Configuring SSH..."
    if [ ! -f /etc/ssh/sshd_config.bak ]; then
        $USE_SUDO cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    fi
    if gum confirm "Do you want to change the default SSH port? (default is 22)"; then
        SSH_PORT=$(gum input --placeholder "Enter new SSH port")
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
            if grep -qE '^#?Port ' /etc/ssh/sshd_config; then
                $USE_SUDO sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
            else
                echo "Port $SSH_PORT" | $USE_SUDO tee -a /etc/ssh/sshd_config > /dev/null
            fi
        else
            gum style --foreground 196 --padding "1 1" "Invalid port number. Skipping port change."
        fi
    fi
    if gum confirm "Do you want to disable root login via SSH?"; then
        if grep -qE '^#?PermitRootLogin ' /etc/ssh/sshd_config; then
            $USE_SUDO sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
        else
            echo "PermitRootLogin no" | $USE_SUDO tee -a /etc/ssh/sshd_config > /dev/null
        fi
    fi
    if gum confirm "Do you want to disable password authentication for SSH?"; then
        if grep -qE '^#?PasswordAuthentication ' /etc/ssh/sshd_config; then
            $USE_SUDO sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
        else
            echo "PasswordAuthentication no" | $USE_SUDO tee -a /etc/ssh/sshd_config > /dev/null
        fi
    fi
    $USE_SUDO systemctl restart sshd
    gum style --foreground 212 --padding "1 1" "SSH configuration completed."
}

firewall_setup() {
    gum style --foreground 57 --padding "1 1" "Installing and configuring Firewall..."
    sleep 1
    $USE_SUDO apt install -y ufw
    if gum confirm "Do you want to allow SSH traffic through the firewall?"; then
        SSH_PORT=$(gum input --placeholder "Enter your SSH port (default is 22)")
        if [ -z "$SSH_PORT" ]; then
            SSH_PORT=22
        fi
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
            if ! $USE_SUDO ufw status | grep -q "$SSH_PORT/tcp"; then
                $USE_SUDO ufw allow $SSH_PORT/tcp
            fi
        else
            gum style --foreground 196 --padding "1 1" "Invalid port number. Skipping SSH port rule."
        fi
    fi
    if gum confirm "Do you want to allow web site traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 80 HTTP traffic..."
        if ! $USE_SUDO ufw status | grep -q "80/tcp"; then
            $USE_SUDO ufw allow 80/tcp comment 'HTTP'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 443 HTTPS traffic..."
        if ! $USE_SUDO ufw status | grep -q "443/tcp"; then
            $USE_SUDO ufw allow 443/tcp comment 'HTTPS'
        fi
    fi
    if gum confirm "Do you want to allow FTP traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 21 FTP traffic..."
        if ! $USE_SUDO ufw status | grep -q "21/tcp"; then
            $USE_SUDO ufw allow 21/tcp comment 'FTP'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for FTP transfers (Ports 12000-12100)..."
        if ! $USE_SUDO ufw status | grep -q "12000:12100/tcp"; then
            $USE_SUDO ufw allow 12000:12100/tcp comment 'FTP Transfers'
        fi
    fi
    if gum confirm "Do you want to allow DNS traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 53 DNS TCP traffic..."
        if ! $USE_SUDO ufw status | grep -q "53/tcp"; then
            $USE_SUDO ufw allow 53/tcp comment 'DNS TCP'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 53 DNS UDP traffic..."
        if ! $USE_SUDO ufw status | grep -q "53/udp"; then
            $USE_SUDO ufw allow 53/udp comment 'DNS UDP'
        fi
    fi
    if gum confirm "Do you want to allow mail traffic (POP3, IMAP, and SMTP) through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 110 POP3 traffic..."
        if ! $USE_SUDO ufw status | grep -q "110/tcp"; then
            $USE_SUDO ufw allow 110/tcp comment 'POP3'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 143 IMAP traffic..."
        if ! $USE_SUDO ufw status | grep -q "143/tcp"; then
            $USE_SUDO ufw allow 143/tcp comment 'IMAP'
        fi
        
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 465 SMTP TLS traffic..."
        if ! $USE_SUDO ufw status | grep -q "465/tcp"; then
            $USE_SUDO ufw allow 465/tcp comment 'SMTP TLS'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 587 SMTP SSL traffic..."
        if ! $USE_SUDO ufw status | grep -q "587/tcp"; then
            $USE_SUDO ufw allow 587/tcp comment 'SMTP SSL'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 993 POP3S traffic..."
        if ! $USE_SUDO ufw status | grep -q "993/tcp"; then
            $USE_SUDO ufw allow 993/tcp comment 'POP3S'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 995 IMAPS traffic..."
        if ! $USE_SUDO ufw status | grep -q "995/tcp"; then
            $USE_SUDO ufw allow 995/tcp comment 'IMAPS'
        fi        
    fi
    if gum confirm "Do you want to allow remote MySQL traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 3306 MySQL traffic..."
        if ! $USE_SUDO ufw status | grep -q "3306/tcp"; then
            $USE_SUDO ufw allow 3306/tcp comment 'MySQL'
        fi
    fi
    if gum confirm "Do you want to allow remote PostgreSQL traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 5432 PostgreSQL traffic..."
        if ! $USE_SUDO ufw status | grep -q "5432/tcp"; then
            $USE_SUDO ufw allow 5432/tcp comment 'PgSQL'
        fi
    fi
    if gum confirm "Do you want to allow Docker (Port 3000) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 3000 Docker traffic..."
        if ! $USE_SUDO ufw status | grep -q "3000/tcp"; then
            $USE_SUDO ufw allow 3000/tcp comment 'Docker'
        fi
    fi
    if gum confirm "Do you want to allow Container Application (Ports 6001, 6002, and 8000) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 6001 Container RTC traffic..."
        if ! $USE_SUDO ufw status | grep -q "6001/tcp"; then
            $USE_SUDO ufw allow 6001/tcp comment 'Container RTC'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 6002 Container SSH traffic..."
        if ! $USE_SUDO ufw status | grep -q "6002/tcp"; then
            $USE_SUDO ufw allow 6002/tcp comment 'Container SSH'
        fi
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 8000 Container traffic..."
        if ! $USE_SUDO ufw status | grep -q "8000/tcp"; then
            $USE_SUDO ufw allow 8000/tcp comment 'Container Controls'
        fi
    fi
    if gum confirm "Do you want to allow Control Panel (Port 8083) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 8083 Control Panel traffic..."
        if ! $USE_SUDO ufw status | grep -q "8083/tcp"; then
            $USE_SUDO ufw allow 8083/tcp comment 'Control Panel'
        fi
    fi
    if gum confirm "Do you want to allow Application Control (Port 8443) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 8443 Application Controls traffic..."
        if ! $USE_SUDO ufw status | grep -q "8443/tcp"; then
            $USE_SUDO ufw allow 8443/tcp comment 'Application Controls'
        fi
    fi
    if gum confirm "Do you want to deny all incoming traffic by default other than the allowed rules?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for denying incoming traffic..."
        $USE_SUDO ufw default deny incoming
    fi
    if gum confirm "Do you want to allow all outgoing traffic by default?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for allowing outgoing traffic..."
        $USE_SUDO ufw default allow outgoing
    fi
    if gum confirm "Do you want to enable the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Enabling firewall..."
        $USE_SUDO ufw enable
    fi
    gum style --foreground 212 --padding "1 1" "Firewall installation and configuration completed."
}

fail2ban_setup() {
    gum style --foreground 57 --padding "1 1" "Installing and configuring Fail2Ban..."
    $USE_SUDO apt install -y fail2ban
    if [ ! -f /etc/fail2ban/jail.local ]; then
        $USE_SUDO cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    fi
    if gum confirm "Do you want to configure Fail2Ban for SSH?"; then
        $USE_SUDO sed -i "s/^#*port\s*=.*/port = ssh/" /etc/fail2ban/jail.local
        $USE_SUDO sed -i "s/^#*enabled\s*=.*/enabled = true/" /etc/fail2ban/jail.local
    fi
    $USE_SUDO systemctl restart fail2ban
    gum style --foreground 212 --padding "1 1" "Fail2Ban configuration completed."
}

unattended_setup() {
    gum style --foreground 57 --padding "1 1" "Installing and configuring unattended upgrades..."
    sleep 1
    $USE_SUDO apt install -y unattended-upgrades
    $USE_SUDO dpkg-reconfigure unattended-upgrades
    gum style --foreground 212 --padding "1 1" "Unattended upgrades configuration completed."
}

apt_fullupdate() {
    gum style --foreground 57 --padding "1 1" "Running a full apt upgrade and package cleanup..."
    sleep 1
    $USE_SUDO apt update
    $USE_SUDO apt install --fix-missing
    $USE_SUDO apt upgrade --allow-downgrades
    $USE_SUDO apt full-upgrade --allow-downgrades -V
    $USE_SUDO apt install -f
    $USE_SUDO apt autoremove --purge
    $USE_SUDO apt autoclean
    $USE_SUDO apt clean
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