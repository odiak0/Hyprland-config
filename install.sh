#!/bin/bash

# Colors for better readability
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# Function to display colored messages
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

# Function to check and install Git
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
            whiptail --title "Error" --msgbox "Failed to clone hyprland-config repository" 8 78
            exit 1
        fi
    fi

    cd "$LINUXTOOLBOXDIR/hyprland-config" || exit
}

# Function to set up AUR helper
setup_aur_helper() {
    print_message "Setting up AUR helper..." "$YELLOW"

    # Ask user to choose between paru and yay using whiptail
    if ! helper=$(whiptail --title "AUR Helper Selection" --menu "Choose your preferred AUR helper:" 15 60 2 \
    "paru" "Rust-based AUR helper" \
    "yay" "Go-based AUR helper" 3>&1 1>&2 2>&3); then
        print_message "AUR helper selection cancelled. Exiting." "$YELLOW"
        exit 1
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
        thunar-media-tags-plugin thunar-volman gvfs google-chrome alacritty waybar
        sddm wget curl unzip btop ffmpeg neovim rofi-wayland ttf-liberation
        pavucontrol wl-clipboard swaybg ffmpegthumbnailer nwg-look nordic-theme
        papirus-icon-theme dunst otf-sora ttf-nerd-fonts-symbols-common otf-firamono-nerd
        inter-font ttf-fantasque-nerd noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
        ttf-icomoon-feather ttf-iosevka-nerd adobe-source-code-pro-fonts ttf-meslo-nerd python-requests
        hyprpicker celluloid brightnessctl xcursor-breeze
    )

    "$helper" -S --noconfirm --needed "${packages[@]}"

    # Enable sddm
    sudo systemctl enable sddm
    sudo systemctl set-default graphical.target
}

# Function to copy configs
copy_configs() {
    print_message "Copying configs..." "$YELLOW"

    # Ask if user is using Hyprland on a laptop using whiptail
    if whiptail --title "Laptop Configuration" --yesno "Are you using Hyprland on a laptop?" 8 78; then
        is_laptop="y"
    else
        is_laptop="n"
    fi

    # Configuration files to copy
    config_files=(
        "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
        "rofi/config.rasi:$HOME/.config/rofi/config.rasi"
        "sddm-theme/aerial:/usr/share/sddm/themes/aerial:sudo"
        "waybar/config.jsonc:/etc/xdg/waybar/config.jsonc:sudo"
        "waybar/style.css:/etc/xdg/waybar/style.css:sudo"
        "waybar/scripts:/etc/xdg/waybar/scripts:sudo,exec"
    )

    # Choose the appropriate Hyprland config based on user input
    if [[ $is_laptop == "y" ]]; then
        config_files+=("hyprland-for-laptop/hyprland.conf:$HOME/.config/hypr/hyprland.conf")
    else
        config_files+=("hyprland/hyprland.conf:$HOME/.config/hypr/hyprland.conf")
    fi

    # Copy each configuration file
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

# Function to copy wallpapers
copy_wallpapers() {
    print_message "Copying wallpapers..." "$YELLOW"
    
    wallpaper_src="$LINUXTOOLBOXDIR/hyprland-config/wallpaper"
    wallpaper_dest="$HOME/wallpaper"

    # Check if source directory exists
    if [ ! -d "$wallpaper_src" ]; then
        whiptail --title "Error" --msgbox "Wallpaper source directory not found: $wallpaper_src" 8 78
        return
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$wallpaper_dest"

    # Copy wallpapers
    if cp -rvf "$wallpaper_src"/* "$wallpaper_dest"; then
        print_message "Wallpapers copied to $wallpaper_dest" "$GREEN"
    else
        whiptail --title "Error" --msgbox "Failed to copy wallpapers" 8 78
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
                whiptail --title "Error" --msgbox "Failed to move fonts to system directory." 8 78
            fi
        else
            whiptail --title "Error" --msgbox "Failed to unzip font file." 8 78
        fi
    else
        whiptail --title "Error" --msgbox "Failed to download font file." 8 78
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