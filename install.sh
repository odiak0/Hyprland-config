#!/bin/bash

# Colors for better readability
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# Function to display colored messages
print_message() {
    local message="$1"
    local color="$2"
    if [ "$color" = "$RED" ]; then
        whiptail --title "Error" --msgbox "$message" 8 78
    else
        echo -e "${color}${message}${ENDCOLOR}"
    fi
}

# Check if pacman exists
if ! command -v pacman &> /dev/null; then
    print_message "Error: pacman not found. This script is intended for Arch-based systems." "$RED"
    exit 1
fi

# Function to check and install Git
check_and_install_git() {
    if ! command -v git &> /dev/null; then
        print_message "Git is not installed. Installing Git..." "$YELLOW"
        sudo pacman -S --noconfirm git
        if command -v git &> /dev/null; then
            print_message "Git has been successfully installed." "$GREEN"
        else
            print_message "Failed to install Git. Please install it manually and run this script again." "$RED"
            exit 1
        fi
    else
        print_message "Git is already installed." "$GREEN"
    fi
}

# Function to setup linuxtoolbox
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
            print_message "Failed to clone hyprland-config repository" "$RED"
            exit 1
        fi
    fi

    cd "$LINUXTOOLBOXDIR/hyprland-config" || exit
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
        ttf-icomoon-feather ttf-iosevka-nerd adobe-source-code-pro-fonts python-requests brightnessctl
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

    # Ask if user is using Hyprland on a laptop
    read -rp "Are you using Hyprland on a laptop? (y/n) " is_laptop

    # Configuration files to move
    config_files=(
        "kitty/kitty.conf:$HOME/.config/kitty/kitty.conf"
        "rofi/config.rasi:$HOME/.config/rofi/config.rasi"
        "sddm-theme/aerial:/usr/share/sddm/themes/aerial:sudo"
        "waybar/config.jsonc:/etc/xdg/waybar/config.jsonc:sudo"
        "waybar/style.css:/etc/xdg/waybar/style.css:sudo"
        "waybar/scripts:/etc/xdg/waybar/scripts:sudo,exec"
    )

    # Choose the appropriate Hyprland config based on user input
    if [[ $is_laptop =~ ^[Yy]$ ]]; then
        config_files+=("hyprland-for-laptop/hyprland.conf:$HOME/.config/hypr/hyprland.conf")
    else
        config_files+=("hyprland/hyprland.conf:$HOME/.config/hypr/hyprland.conf")
    fi

    # Move each configuration file
    for config in "${config_files[@]}"; do
        IFS=':' read -r src dest action <<< "$config"
        src="$LINUXTOOLBOXDIR/hyprland-config/$src"
        
        if [ ! -e "$src" ]; then
            print_message "Source does not exist: $src" "$RED"
            continue
        fi

        if [[ "$action" == *"sudo"* ]]; then
            sudo mkdir -p "$(dirname "$dest")"
            if sudo mv -vf "$src" "$dest"; then
                print_message "Successfully moved $src to $dest" "$GREEN"
            else
                print_message "Failed to move $src to $dest" "$RED"
            fi
        else
            mkdir -p "$(dirname "$dest")"
            if mv -vf "$src" "$dest"; then
                print_message "Successfully moved $src to $dest" "$GREEN"
            else
                print_message "Failed to move $src to $dest" "$RED"
            fi
        fi

        if [[ "$action" == *"exec"* ]]; then
            if [[ "$action" == *"sudo"* ]]; then
                sudo find "$dest" -type f -name "*.py" -exec chmod +x {} +
            else
                find "$dest" -type f -name "*.py" -exec chmod +x {} +
            fi
            print_message "Made Python scripts in $dest executable" "$GREEN"
        fi
    done
}

# Function to move wallpapers
move_wallpapers() {
    print_message "Moving wallpapers..." "$YELLOW"
    
    wallpaper_src="$LINUXTOOLBOXDIR/hyprland-config/wallpaper"
    wallpaper_dest="$HOME/wallpaper"

    # Check if source directory exists
    if [ ! -d "$wallpaper_src" ]; then
        print_message "Wallpaper source directory not found: $wallpaper_src" "$RED"
        return
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$wallpaper_dest"

    # Move wallpapers
    if mv -v "$wallpaper_src"/* "$wallpaper_dest"; then
        print_message "Wallpapers moved to $wallpaper_dest" "$GREEN"
    else
        print_message "Failed to move wallpapers" "$RED"
    fi
}

# Function to install additional fonts
install_additional_fonts() {
    print_message "Installing additional fonts..." "$YELLOW"
    
    local font_dir="$HOME/Downloads/nerdfonts"
    local font_zip="CascadiaCode.zip"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.1/$font_zip"
    
    mkdir -p "$font_dir"
    cd "$HOME/Downloads" || exit
    
    if wget "$font_url"; then
        if unzip "$font_zip" -d "$font_dir"; then
            rm -f "$font_zip"
            if sudo mv "$font_dir" /usr/share/fonts/; then
                fc-cache -fv
                print_message "Cascadia Code Nerd Font installed successfully." "$GREEN"
            else
                print_message "Failed to move fonts to system directory." "$RED"
            fi
        else
            print_message "Failed to unzip font file." "$RED"
        fi
    else
        print_message "Failed to download font file." "$RED"
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

    if whiptail --title "Install Packages" --yesno "Would you like to install the packages?" 8 78; then
        install_packages
    else
        print_message "No packages installed." "$YELLOW"
    fi

    if whiptail --title "Move Configs" --yesno "Would you like to move the configs?\n\nWARNING: This will overwrite existing configuration files. Make sure you have backups if needed." 12 78; then
        move_configs
    else
        print_message "No configs moved." "$YELLOW"
    fi

    if whiptail --title "Move Wallpapers" --yesno "Would you like to move the wallpapers?" 8 78; then
        move_wallpapers
    else
        print_message "No wallpapers moved." "$YELLOW"
    fi

    if whiptail --title "Install Fonts" --yesno "Would you like to install fonts for waybar (strongly recommended)?" 8 78; then
        install_additional_fonts
    else
        print_message "Cascadia Code font not installed." "$YELLOW"
    fi

    if whiptail --title "Install NVIDIA Drivers" --yesno "Would you like to install NVIDIA drivers?" 8 78; then
        install_nvidia_drivers
    else
        print_message "NVIDIA drivers not installed." "$YELLOW"
    fi

    whiptail --title "Installation Complete" --msgbox "Installation completed. You can now reboot your system!" 8 78
}

# Run the main function
main