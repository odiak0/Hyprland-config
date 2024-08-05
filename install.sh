#!/bin/bash

# Colors for better readability
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# Check if pacman exists
if ! command -v pacman &> /dev/null; then
    print_message "Error: pacman not found. This script is intended for Arch-based systems." "$RED"
    exit 1
fi

# Function to setup linuxtoolbox
setup_linuxtoolbox() {
    LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

    if [ ! -d "$LINUXTOOLBOXDIR" ]; then
        print_message "Creating linuxtoolbox directory: $LINUXTOOLBOXDIR" "$YELLOW"
        mkdir -p "$LINUXTOOLBOXDIR"
        print_message "linuxtoolbox directory created: $LINUXTOOLBOXDIR" "$GREEN"
    fi

    if [ ! -d "$LINUXTOOLBOXDIR/hyprland-config" ]; then
        print_message "Cloning hyprland-config repository into: $LINUXTOOLBOXDIR/hyprland-config" "$YELLOW"
        if git clone https://github.com/odiak0/hyprland-config "$LINUXTOOLBOXDIR/hyprland-config"; then
            print_message "Successfully cloned hyprland-config repository" "$GREEN"
        else
            print_message "Failed to clone hyprland-config repository" "$RED"
            exit 1
        fi
    fi

    cd "$LINUXTOOLBOXDIR/hyprland-config" || exit
}

# Function to display colored messages
print_message() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${ENDCOLOR}"
}

# Function to set up AUR helper
setup_aur_helper() {
    # Ask user to choose between paru and yay
    read -rp "Do you want to use paru or yay as your AUR helper? (p/y) " aur_helper
    if [[ $aur_helper =~ ^[Pp]$ ]]; then
        helper="paru"
    else
        helper="yay"
    fi

    # Install chosen AUR helper if not present
    if ! command -v "$helper" &> /dev/null; then
        print_message "Installing $helper..." "$YELLOW"
        cd || exit
        git clone "https://aur.archlinux.org/$helper.git"
        cd "$helper" || exit
        makepkg -si --noconfirm --needed
        cd .. && rm -rf "$helper"
    fi
}

# Function to install packages
install_packages() {
    print_message "Installing packages..." "$YELLOW"

    setup_aur_helper

    # List of packages to install
    packages=(
        hyprland lxsession thunar pamixer flameshot fastfetch fuse2 xarchiver
        xdg-desktop-portal-gtk xdg-desktop-portal-hyprland thunar-archive-plugin
        thunar-media-tags-plugin thunar-volman gvfs google-chrome kitty waybar
        sddm wget curl unzip btop ffmpeg neovim rofi-wayland ttf-liberation
        pavucontrol wl-clipboard swaybg ffmpegthumbnailer nwg-look nordic-theme
        papirus-icon-theme dunst otf-sora ttf-nerd-fonts-symbols-common otf-firamono-nerd
        inter-font ttf-fantasque-nerd noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
        ttf-icomoon-feather ttf-iosevka-nerd adobe-source-code-pro-fonts brightnessctl
        hyprpicker
    )

    "$helper" -S --noconfirm --needed "${packages[@]}"

    # Enable sddm
    sudo systemctl enable sddm
    sudo systemctl set-default graphical.target
}

# Function to move configs
move_configs() {
    print_message "Moving configs..." "$YELLOW"

    # Configuration files to move
    config_files=(
        "hyprland/hyprland.conf:~/.config/hypr/hyprland.conf"
        "kitty/kitty.conf:~/.config/kitty/kitty.conf"
        "rofi/config.rasi:~/.config/rofi/config.rasi"
        "sddm-theme/aerial/:/usr/share/sddm/themes/aerial/"
        "waybar/config.jsonc:/etc/xdg/waybar/config.jsonc"
        "waybar/style.css:/etc/xdg/waybar/style.css"
        "waybar/scripts/:/etc/xdg/waybar/scripts/:exec"
    )

    # Move each configuration file
    for config in "${config_files[@]}"; do
        IFS=':' read -r src dest exec_flag <<< "$config"
        sudo mkdir -p "$(dirname "$dest")"
        if sudo mv -vf "$LINUXTOOLBOXDIR/hyprland-config/$src" "$dest"; then
            print_message "Successfully moved $src to $dest" "$GREEN"
        else
            print_message "Failed to move $src to $dest" "$RED"
        fi
        if [[ "$exec_flag" == "exec" ]]; then
            sudo chmod +x "${dest}waybar-wttr.py"
        fi
    done

    # Move wallpapers
    mkdir -p ~/wallpaper
    if mv -vf "$LINUXTOOLBOXDIR/hyprland-config/wallpaper/"* ~/wallpaper; then
        print_message "Wallpapers moved successfully." "$GREEN"
    else
        print_message "Failed to move wallpapers." "$RED"
    fi
    
    # Install additional fonts
    print_message "Installing additional fonts..." "$YELLOW"
    mkdir -p "$HOME/Downloads/nerdfonts/"
    cd "$HOME/Downloads/" || { print_message "Failed to change directory to Downloads." "$RED"; return 1; }
    
    if wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.1/CascadiaCode.zip; then
        print_message "CascadiaCode.zip downloaded successfully." "$GREEN"
    else
        print_message "Failed to download CascadiaCode.zip." "$RED"
        return 1
    fi
    
    if unzip 'CascadiaCode.zip' -d "$HOME/Downloads/nerdfonts/"; then
        print_message "CascadiaCode.zip extracted successfully." "$GREEN"
    else
        print_message "Failed to extract CascadiaCode.zip." "$RED"
        return 1
    fi
    
    rm -rf CascadiaCode.zip
    
    if sudo mv "$HOME/Downloads/nerdfonts/" /usr/share/fonts/; then
        print_message "Fonts moved to system directory successfully." "$GREEN"
    else
        print_message "Failed to move fonts to system directory." "$RED"
        return 1
    fi

    if fc-cache -fv; then
        print_message "Font cache updated successfully." "$GREEN"
    else
        print_message "Failed to update font cache." "$RED"
    fi
}

# Function to install NVIDIA drivers
install_nvidia_drivers() {
    print_message "Installing NVIDIA drivers..." "$YELLOW"
    
    # Ensure AUR helper is set up
    if [ -z "$helper" ]; then
        setup_aur_helper
    fi
    
    "$helper" -S --noconfirm nvidia-dkms lib32-nvidia-utils
}

# Main function
main() {
    setup_linuxtoolbox

    print_message "Updating system..." "$YELLOW"
    sudo pacman -Syu

    read -rp "Would you like to install the packages? (y/n) " pkgs
    if [[ $pkgs =~ ^[Yy]$ ]]; then
        install_packages
    else
        print_message "No packages installed." "$RED"
    fi

    read -rp "Would you like to move the configs? (y/n) " configs
    if [[ $configs =~ ^[Yy]$ ]]; then
        move_configs
    else
        print_message "No configs moved." "$RED"
    fi

    read -rp "Would you like to install NVIDIA drivers? (y/n) " nvidia
    if [[ $nvidia =~ ^[Yy]$ ]]; then
        install_nvidia_drivers
    else
        print_message "NVIDIA drivers not installed." "$RED"
    fi

    print_message "Installation completed. You can now reboot your system!" "$GREEN"
}

# Run the main function
main