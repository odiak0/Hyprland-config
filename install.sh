#!/bin/bash

GREEN="\e[32m"
ENDCOLOR="\e[0m"

### Updating system ###

sudo pacman -Syu

read -rep "Would you like to install the packages? (y/n)" pkgs
echo

if [[ $pkgs =~ ^[Nn]$ ]]; then
    printf "No packages installed. \n"
fi

if [[ $pkgs =~ ^[Yy]$ ]]; then
    printf "Installing packages. \n"

### Installing yay ###

cd || exit
git clone https://aur.archlinux.org/yay.git
cd yay || exit
makepkg -si --noconfirm --needed
rm -rf ~/yay

### Installing packages ###

yay -S --noconfirm --needed hyprland lxsession thunar pamixer flameshot fastfetch fuse2 xarchiver xdg-desktop-portal-gtk xdg-desktop-portal-hyprland thunar-archive-plugin thunar-media-tags-plugin thunar-volman gvfs google-chrome kitty waybar sddm wget curl unzip btop ffmpeg neovim rofi-wayland ttf-liberation pavucontrol wl-clipboard swaybg ffmpegthumbnailer nwg-look-bin nordic-theme papirus-icon-theme dunst otf-sora ttf-nerd-fonts-symbols-common otf-firamono-nerd inter-font ttf-fantasque-nerd noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-icomoon-feather ttf-iosevka-nerd adobe-source-code-pro-fonts brightnessctl hyprpicker

### Enabling sddm ###

sudo systemctl enable sddm
sudo systemctl set-default graphical.target
fi

read -rep "Would you like to move the configs? (y/n)" configs
echo

if [[ $configs =~ ^[Nn]$ ]]; then
    printf "No configs moved. \n"
fi

if [[ $configs =~ ^[Yy]$ ]]; then
	printf "Moving configs. \n"

### Moving configs ###

cd ~/hyprland-config/ || exit
mkdir ~/.config/hypr
mv -vf ~/hyprland-config/hyprland/hyprland.conf ~/.config/hypr/
mkdir ~/.config/kitty
mv -vf ~/hyprland-config/kitty/kitty.conf ~/.config/kitty/
mkdir ~/.config/rofi
mv -vf ~/hyprland-config/rofi/config.rasi ~/.config/rofi/
sudo mv -vf ~/hyprland-config/sddm-theme/aerial/ /usr/share/sddm/themes/
mkdir ~/wallpaper
mv -vf ~/hyprland-config/wallpaper/* ~/wallpaper
sudo mv -vf ~/hyprland-config/waybar/config.jsonc /etc/xdg/waybar/
sudo mv -vf ~/hyprland-config/waybar/style.css /etc/xdg/waybar/
sudo rm -rf /etc/xdg/waybar/config
sudo mv -vf ~/hyprland-config/waybar/scripts/ /etc/xdg/waybar/
sudo chmod +x /etc/xdg/waybar/scripts/waybar-wttr.py

### Fonts for Waybar ###

mkdir -p "$HOME"/Downloads/nerdfonts/
cd "$HOME"/Downloads/ || exit
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.1/CascadiaCode.zip
unzip 'CascadiaCode.zip' -d "$HOME"/Downloads/nerdfonts/
rm -rf CascadiaCode.zip
sudo mv "$HOME"/Downloads/nerdfonts/ /usr/share/fonts/

fc-cache -rv
fi

read -rep "Would you like to install nvidia drivers? (y/n)" nvidia
echo

if [[ $nvidia =~ ^[Nn]$ ]]; then
    printf "Not installed. \n"
fi

if [[ $nvidia =~ ^[Yy]$ ]]; then
	printf "Installing nvidia drivers. \n"

### Installing nvidia drivers ###

yay -S --noconfirm nvidia-dkms lib32-nvidia-utils
fi

echo -e "${GREEN}Now you can reboot!${ENDCOLOR}"