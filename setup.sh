#!/bin/bash
# +----------------------------------------------------------------------------+
# |          setup.sh - A simple script to setup Debian environments.          |
# +----------------------------------------------------------------------------+
set -euo pipefail

setup_start(){
    echo ""
    echo "+------------------------------------------------------------------------------+"
    echo "|       This script will configure this environment for development use.       |"
    echo "|                                                                              |"
    echo "|     It will guide you through a series of prompts to setup useful Debian     |"
    echo "|   packages such as development tools, npm, gum, and other useful packages.   |"
    echo "+------------------------------------------------------------------------------+"
    echo ""
    echo " If you don't want to continue, press Control-C now to exit the script."
    echo ""
    read -p " If you are ready to proceed, press [Enter] to start the script..."
    echo ""
}

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

localetime_setup() {
    gum style --foreground 57 --padding "1 1" "Running Configuration Utility to set Environment Locale..."
    sleep 1
    $USE_SUDO dpkg-reconfigure locales
    gum style --foreground 57 --padding "1 1" "Running Configuration Utility to set Environment Timezone..."
    sleep 1
    $USE_SUDO dpkg-reconfigure tzdata
    gum style --foreground 212 --padding "1 1" "Environment Locale and Timezone have been set and updated."
}

apt_update() {
    gum style --foreground 57 --padding "1 1" "Updating package lists..."
    sleep 1
    $USE_SUDO apt update
    gum style --foreground 212 --padding "1 1" "Local package listings have been updated."
    gum style --foreground 57 --padding "1 1" "Updating installed packages..."
    sleep 1
    $USE_SUDO apt upgrade -y && $USE_SUDO apt full-upgrade -y
    gum style --foreground 212 --padding "1 1" "Installed packages have been updated."
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

pkgbase_setup() {
    gum style --foreground 57 --padding "1 1" "Installing common packages for development servers..."
    sleep 1
    $USE_SUDO apt install -y apt-transport-https btop build-essential bwm-ng ca-certificates cmake cmatrix debian-goodies duf git glances htop iotop locate iftop jq make multitail nano needrestart net-tools p7zip p7zip-full tar tldr-py tree unzip vnstat
    gum style --foreground 212 --padding "1 1" "Common packages for development servers have been installed."
    if [ "$DEBIAN_VERSION" -lt 13 ]; then
        gum style --foreground 57 --padding "1 1" "Installing common packages specific to Debian 12..."
        sleep 1
        echo 'deb [signed-by=/usr/share/keyrings/azlux.gpg] https://packages.azlux.fr/debian/ bookworm main' | $USE_SUDO tee /etc/apt/sources.list.d/azlux.list
        curl -s https://azlux.fr/repo.gpg.key | gpg --dearmor | $USE_SUDO tee /usr/share/keyrings/azlux.gpg > /dev/null
        $USE_SUDO apt update && $USE_SUDO apt install -y software-properties-common gping
        gum style --foreground 212 --padding "1 1" "Common packages specific to Debian 12 have been installed."
    fi
    if [ "$DEBIAN_VERSION" -ge 13 ]; then
        gum style --foreground 57 --padding "1 1" "Installing common packages specific to Debian 13..."
        sleep 1
        $USE_SUDO apt install -y gping
        gum style --foreground 212 --padding "1 1" "Common packages specific to Debian 13 have been installed."
    fi
}

pkgoptions_setup() {
    gum style --foreground 57 --padding "1 1" "Choose optional packages to install:"
    readarray -t ENV_OPTIONS < <(gum choose --no-limit \
        "Go Programming Language Support" \
        "Node.js Support and Node Package Manager" \
        "Starship Prompt Enhancements" \
        "System Information Utilities" \
        "Tailscale Virtual Networking" \
        "Local LLMs powered by Ollama" \
        "Terminal AI Coding Agents" \
        "Terminal Multiplexer")
    for OPTION in "${ENV_OPTIONS[@]}"; do
        case $OPTION in
            "Go Programming Language Support")
                gum style --foreground 57 --padding "1 1" "Installing go language support from Debian package repositories..."
                sleep 1
                $USE_SUDO apt install -y golang
                gum style --foreground 212 --padding "1 1" "Go language support has been installed."
                ;;
            "Node.js Support and Node Package Manager")
                gum style --foreground 57 --padding "1 1" "Installing node.js support and npm from Debian package repositories..."
                sleep 1
                $USE_SUDO apt install -y nodejs npm
                gum style --foreground 212 --padding "1 1" "Node.js support and npm have been installed."
                ;;
            "Starship Prompt Enhancements")
                gum style --foreground 57 --padding "1 1" "Installing starship prompt enchancements..."
                sleep 1
                if ! command -v starship &> /dev/null; then
                    curl -sS https://starship.rs/install.sh | sh
                    echo "eval \"\$(starship init bash)\"" >> $HOME/.bashrc
                fi
                if [ ! -d "$HOME/.config" ]; then
                    mkdir -p "$HOME/.config"
                fi
                touch $HOME/.config/starship.toml
                starship preset plain-text-symbols -o $HOME/.config/starship.toml
                echo "if [ -f /usr/bin/fastfetch ]; then fastfetch; fi" >> $HOME/.bashrc
                gum style --foreground 212 --padding "1 1" "Starship prompt enchancements have been installed."
                ;;
            "System Information Utilities")
                gum style --foreground 57 --padding "1 1" "Installing system information utilities..."
                sleep 1
                $USE_SUDO apt install -y hwinfo sysstat
                gum style --foreground 212 --padding "1 1" "System information utilties have been installed."
                ;;
            "Tailscale Virtual Networking")
                gum style --foreground 57 --padding "1 1" "Installing Tailscale virtual networking..."
                sleep 1
                $USE_SUDO curl -fsSL https://tailscale.com/install.sh | sh
                gum style --foreground 57 --padding "1 1" "Prompting for Tailscale activation..."
                $USE_SUDO tailscale up
                if gum confirm "Do you want this environment to be an exit node?"; then
                    $USE_SUDO tailscale set --advertise-exit-node=true
                    echo 'net.ipv4.ip_forward = 1' | $USE_SUDO tee -a /etc/sysctl.d/99-tailscale.conf
                    echo 'net.ipv6.conf.all.forwarding = 1' | $USE_SUDO tee -a /etc/sysctl.d/99-tailscale.conf
                    $USE_SUDO sysctl -p /etc/sysctl.d/99-tailscale.conf
                else
                    $USE_SUDO tailscale set --advertise-exit-node=false
                fi
                $USE_SUDO tailscale set --accept-routes=false
                $USE_SUDO tailscale set --accept-dns=false
                gum style --foreground 212 --padding "1 1" "Tailscale virtual networking has been installed."
                ;;
            "Local LLMs powered by Ollama")
                gum style --foreground 57 --padding "1 1" "Installing Ollama for Local LLM use..."
                sleep 1
                $USE_SUDO curl -fsSL https://ollama.com/install.sh | sh
                gum style --foreground 212 --padding "1 1" "Ollama for Local LLM use has been installed."
                ;;
            "Terminal AI Coding Agents")
                if ! command -v npm &> /dev/null; then
                    gum style --foreground 57 --padding "1 1" "Installing required packages for coding agents..."
                    sleep 1
                    $USE_SUDO apt install -y npm
                    gum style --foreground 212 --padding "1 1" "The required packages have been installed."
                fi
                gum style --foreground 57 --padding "1 1" "Installing Crush from Charm..."
                sleep 1
                $USE_SUDO apt install -y crush
                gum style --foreground 212 --padding "1 1" "Charm Crush has been installed."
                gum style --foreground 57 --padding "1 1" "Installing Opencode..."
                sleep 1
                $USE_SUDO npm install -g opencode-ai@latest
                gum style --foreground 212 --padding "1 1" "Opencode has been installed."
                ;;
            "Terminal Multiplexer")
                gum style --foreground 57 --padding "1 1" "Installing tmux from Debian package repositories..."
                sleep 1
                $USE_SUDO apt install -y tmux
                gum style --foreground 212 --padding "1 1" "Tmux has been installed."
                ;;
            *)
                gum style --foreground 57 --padding "1 1" "No optional packages selected, skipping..."
                sleep 1
                ;;
        esac
    done
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
            $USE_SUDO ufw allow $SSH_PORT/tcp
        else
            gum style --foreground 196 --padding "1 1" "Invalid port number. Skipping SSH port rule."
        fi
    fi
    if gum confirm "Do you want to allow web site traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 80 HTTP traffic..."
        $USE_SUDO ufw allow 80/tcp comment 'HTTP'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 443 HTTPS traffic..."
        $USE_SUDO ufw allow 443/tcp comment 'HTTPS'
    fi
    if gum confirm "Do you want to allow FTP traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 20 FTP transfer traffic..."
        $USE_SUDO ufw allow 20/tcp comment 'FTP Transfer'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 21 FTP control traffic..."
        $USE_SUDO ufw allow 21/tcp comment 'FTP Control'
    fi
    if gum confirm "Do you want to allow DNS traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 53 DNS TCP traffic..."
        $USE_SUDO ufw allow 53/tcp comment 'DNS TCP'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 53 DNS UDP traffic..."
        $USE_SUDO ufw allow 53/udp comment 'DNS UDP'
    fi
    if gum confirm "Do you want to allow mail traffic (POP3, IMAP, and SMTP) through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 110 POP3 traffic..."
        $USE_SUDO ufw allow 110/tcp comment 'POP3'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 143 IMAP traffic..."
        $USE_SUDO ufw allow 143/tcp comment 'IMAP'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 465 SMTP TLS traffic..."
        $USE_SUDO ufw allow 465/tcp comment 'SMTP TLS'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 587 SMTP SSL traffic..."
        $USE_SUDO ufw allow 587/tcp comment 'SMTP SSL'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 993 POP3S traffic..."
        $USE_SUDO ufw allow 993/tcp comment 'POP3S'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 995 IMAPS traffic..."
        $USE_SUDO ufw allow 995/tcp comment 'IMAPS'
    fi
    if gum confirm "Do you want to allow remote MySQL traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 3306 MySQL traffic..."
        $USE_SUDO ufw allow 3306/tcp comment 'MySQL'
    fi
    if gum confirm "Do you want to allow remote PostgreSQL traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 5432 PostgreSQL traffic..."
        $USE_SUDO ufw allow 5432/tcp comment 'PgSQL'
    fi
    if gum confirm "Do you want to allow Docker (Port 3000) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 3000 Docker traffic..."
        $USE_SUDO ufw allow 3000/tcp comment 'Docker'
    fi
    if gum confirm "Do you want to allow Container Application (Ports 6001, 6002, and 8000) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 6001 Container RTC traffic..."
        $USE_SUDO ufw allow 6001/tcp comment 'Container RTC'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 6002 Container SSH traffic..."
        $USE_SUDO ufw allow 6002/tcp comment 'Container SSH'
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 8000 Container traffic..."
        $USE_SUDO ufw allow 8000/tcp comment 'Container Controls'
    fi
    if gum confirm "Do you want to allow Control Panel (Port 8083) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 8083 Control Panel traffic..."
        $USE_SUDO ufw allow 8083/tcp comment 'Control Panel'
    fi
    if gum confirm "Do you want to allow Application Control (Port 8443) traffic through the firewall?"; then
        gum style --foreground 57 --padding "1 1" "Adding rule for Port 8443 Application Controls traffic..."
        $USE_SUDO ufw allow 8443/tcp comment 'Application Controls'
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

setup_start
connection_check
version_check
sudo_check
deps_check
gum_check
localetime_setup
apt_update
fastfetch_setup
pkgbase_setup
pkgoptions_setup
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