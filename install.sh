#!/bin/bash

GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

print_message() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${ENDCOLOR}"
}

# Check if pacman exists
if ! command -v pacman &> /dev/null; then
    whiptail --title "Error" --msgbox "Error: pacman not found. This script is intended for Arch-based systems." 8 78
    exit 1
fi

check_and_install_git() {
    if ! command -v git &> /dev/null; then
        print_message "Git is not installed. Installing Git..." "$YELLOW"
        sudo pacman -S --noconfirm git
        if command -v git &> /dev/null; then
            print_message "Git has been successfully installed." "$GREEN"
        else
            whiptail --title "Error" --msgbox "Failed to install Git. Please install it manually and run this script again." 8 78
            exit 1
        fi
    else
        print_message "Git is already installed." "$GREEN"
    fi
}

setup_linuxtoolbox() {
    check_and_install_git

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
            whiptail --title "Error" --msgbox "Failed to clone hyprland-config repository" 8 78
            exit 1
        fi
    fi

    cd "$LINUXTOOLBOXDIR/hyprland-config" || exit
}

setup_aur_helper() {
    print_message "Setting up AUR helper..." "$YELLOW"

    if ! helper=$(whiptail --title "AUR Helper Selection" --menu "Choose your preferred AUR helper:" 15 60 2 \
    "paru" "Rust-based AUR helper" \
    "yay" "Go-based AUR helper" 3>&1 1>&2 2>&3); then
        print_message "AUR helper selection cancelled. Exiting." "$YELLOW"
        exit 1
    fi

    if ! command -v "$helper" &> /dev/null; then
        print_message "Installing $helper..." "$YELLOW"
        cd || exit
        git clone "https://aur.archlinux.org/$helper.git"
        cd "$helper" || exit
        makepkg -si --noconfirm --needed
        cd .. && rm -rf "$helper"
    fi
}

install_packages() {
    print_message "Installing packages..." "$YELLOW"

    setup_aur_helper

    packages=(
        hyprland hyprpolkitagent thunar pamixer fastfetch fuse2 xarchiver
        xdg-desktop-portal-gtk xdg-desktop-portal-hyprland thunar-archive-plugin
        thunar-media-tags-plugin thunar-volman gvfs google-chrome alacritty waybar
        sddm wget curl unzip btop ffmpeg neovim rofi-wayland ttf-liberation
        pavucontrol wl-clipboard swww ffmpegthumbnailer nwg-look grim slurp
        papirus-icon-theme dunst ttf-nerd-fonts-symbols-common otf-firamono-nerd
        inter-font ttf-fantasque-nerd noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
        ttf-iosevka-nerd ttf-meslo-nerd python-requests cantarell-fonts
        hyprpicker celluloid brightnessctl xcursor-breeze
    )

    "$helper" -S --noconfirm --needed "${packages[@]}"

    # Enable sddm
    sudo systemctl enable sddm
    sudo systemctl set-default graphical.target
}

copy_configs() {
    print_message "Copying configs..." "$YELLOW"

    # Ask if user is using Hyprland on a laptop
    if whiptail --title "Laptop Configuration" --yesno "Are you using Hyprland on a laptop?" 8 78; then
        is_laptop="y"
    else
        is_laptop="n"
    fi

    config_files=(
        "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
        "rofi/config.rasi:$HOME/.config/rofi/config.rasi"
        "sddm-theme/aerial:/usr/share/sddm/themes/aerial:sudo"
        "waybar/config.jsonc:/etc/xdg/waybar/config.jsonc:sudo"
        "waybar/style.css:/etc/xdg/waybar/style.css:sudo"
    )

    if [[ $is_laptop == "y" ]]; then
        config_files+=("hyprland-for-laptop/hyprland.conf:$HOME/.config/hypr/hyprland.conf")
    else
        config_files+=("hyprland/hyprland.conf:$HOME/.config/hypr/hyprland.conf")
    fi

    for config in "${config_files[@]}"; do
        IFS=':' read -r src dest action <<< "$config"
        src="$LINUXTOOLBOXDIR/hyprland-config/$src"
        
        if [ ! -e "$src" ]; then
            whiptail --title "Error" --msgbox "Source does not exist: $src" 8 78
            continue
        fi

        if [[ "$action" == *"sudo"* ]]; then
            sudo mkdir -p "$(dirname "$dest")"
            if sudo cp -rvf "$src" "$dest"; then
                print_message "Successfully copied $src to $dest" "$GREEN"
            else
                whiptail --title "Error" --msgbox "Failed to copy $src to $dest" 8 78
            fi
        else
            mkdir -p "$(dirname "$dest")"
            if cp -rvf "$src" "$dest"; then
                print_message "Successfully copied $src to $dest" "$GREEN"
            else
                whiptail --title "Error" --msgbox "Failed to copy $src to $dest" 8 78
            fi
        fi
    done

    # Install theme
    if sudo git clone https://github.com/EliverLara/Nordic.git /usr/share/themes/Nordic; then
        print_message "Installed Nordic theme successfully" "$GREEN"
    else
        whiptail --title "Error" --msgbox "Failed to install Nordic theme" 8 78
    fi
}

copy_wallpapers() {
    print_message "Copying wallpapers..." "$YELLOW"

    # Copy wallpapers
    mkdir -p ~/wallpaper
    if cp -rvf "$LINUXTOOLBOXDIR/hyprland-config/wallpaper/"* ~/wallpaper; then
        print_message "Copied wallpapers successfully" "$GREEN"
    else
        whiptail --title "Error" --msgbox "Failed to copy wallpapers" 8 78
    fi
}

install_nvidia_drivers() {
    print_message "Installing NVIDIA drivers..." "$YELLOW"
    
    # Ensure AUR helper is set up
    if [ -z "$helper" ]; then
        setup_aur_helper
    fi
    
    "$helper" -S --noconfirm nvidia-dkms lib32-nvidia-utils
}

main() {
    setup_linuxtoolbox

    print_message "Updating system..." "$YELLOW"
    sudo pacman -Syu

    if whiptail --title "Install Packages" --yesno "Would you like to install the packages?" 8 78; then
        install_packages
    else
        print_message "No packages installed." "$YELLOW"
    fi

    if whiptail --title "Copy Configs" --yesno "Would you like to copy the configs?\n\nWARNING: This will overwrite existing configuration files. Make sure you have backups if needed." 12 78; then
        copy_configs
    else
        print_message "No configs copied." "$YELLOW"
    fi

    if whiptail --title "Copy Wallpapers" --yesno "Would you like to copy the wallpapers?" 8 78; then
        copy_wallpapers
    else
        print_message "No wallpapers copied." "$YELLOW"
    fi

    if whiptail --title "Install NVIDIA Drivers" --yesno "Would you like to install NVIDIA drivers?" 8 78; then
        install_nvidia_drivers
    else
        print_message "NVIDIA drivers not installed." "$YELLOW"
    fi

    whiptail --title "Installation Complete" --msgbox "Installation completed. You can now reboot your system!" 8 78
}

main