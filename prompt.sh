#!/bin/bash
# +----------------------------------------------------------------------------+
# |    prompt.sh - A simple script to setup the Starship prompt for a user.    |
# +----------------------------------------------------------------------------+
set -euo pipefail

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

source ./common.sh
connection_check
version_check
sudo_check
deps_check
gum_check
fastfetch_setup
cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%s)" || { echo " Error: Backup of .bashrc failed."; exit 1; }
starship_setup
starship_config
exit 0