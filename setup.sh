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
                gum style --foreground 57 --padding "1 1" "Installing starship prompt enhancements..."
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
                gum style --foreground 212 --padding "1 1" "Starship prompt enhancements have been installed."
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
                $USE_SUDO tailscale up --qr
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

setup_start
source ./common.sh
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