#!/bin/bash
# +----------------------------------------------------------------------------+
# |    prompt.sh - A simple script to setup the Starship prompt for a user.    |
# +----------------------------------------------------------------------------+
set -e

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
gum_check

# Verify "starship" is installed and install from home page if missing
gum style --foreground 57 --padding "1 1" "Checking that starship is already installed..."
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh
fi

# Check for entry in .bashrc to enable "starship"
gum style --foreground 57 --padding "1 1" "Adding starship to the bash shell..."
if ! grep -q "eval \"\$(starship init bash)\"" "$HOME/.bashrc"; then
    echo "eval \"\$(starship init bash)\"" >> "$HOME/.bashrc"
fi

# Check for local config directory and starship.toml and create if it does't exist
gum style --foreground 57 --padding "1 1" "Installing the plain text prompt presets..."
if [ ! -d "$HOME/.config" ]; then
    mkdir -p "$HOME/.config"
fi
touch $HOME/.config/starship.toml
starship preset plain-text-symbols -o $HOME/.config/starship.toml

# Setup the bash login and add "fastfetch" & useful tools to the user's .bashrc
if ! grep -q "if [ -f /usr/bin/fastfetch ]; then fastfetch; fi" "$HOME/.bashrc"; then
    echo "if [ -f /usr/bin/fastfetch ]; then fastfetch; fi" >> "$HOME/.bashrc"
fi

# Let the user know the script is complete and exit cleanly
gum style --foreground 212 --padding "1 1" "Starship has been configured and will be available on your next login."
exit 0