#!/bin/bash

### Installing yay ###

cd
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
rm -rf ~/yay

### Installing packages ###

sudo pacman -S --noconfirm thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman gvfs kitty waybar sddm wget unzip

yay -S --noconfirm hyprland polkit-gnome ffmpeg neovim viewnior rofi pavucontrol wl-clipboard wf-recorder swaybg grimblast-git ffmpegthumbnailer tumbler playerctl noise-suppression-for-voice nwg-look-bin nordic-theme papirus-icon-theme dunst otf-sora ttf-nerd-fonts-symbols-common otf-firamono-nerd inter-font ttf-fantasque-nerd noto-fonts noto-fonts-emoji ttf-comfortaa ttf-jetbrains-mono-nerd ttf-icomoon-feather ttf-iosevka-nerd adobe-source-code-pro-fonts brightnessctl hyprpicker-git

### Fonts for Waybar ###

mkdir -p $HOME/Downloads/nerdfonts/
cd $HOME/Downloads/
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.1/CascadiaCode.zip
unzip 'CascadiaCode.zip' -d $HOME/Downloads/nerdfonts/
rm -rf *.zip
sudo mv $HOME/Downloads/nerdfonts/ /usr/share/fonts/

fc-cache -rv

### Moving configs ###

cd ~/hyprland-config
cd hyprland/
mkdir ~/.config/hypr
sudo mv -f hyprland.conf ~/.config/hypr/
cd ..
cd kitty/
mkdir ~/.config/kitty
sudo mv -f kitty.conf ~/.config/kitty/
cd ..
cd rofi/
mkdir ~/.config/rofi
sudo mv -f config.rasi ~/.config/rofi/
cd ..
cd sddm-theme/
sudo mv -f aerial/ /usr/share/sddm/themes/
cd ..
cd wallpaper/
mkdir /usr/share/hyprland
sudo mv -f mazda.jpg /usr/share/hyprland/
cd ..
cd waybar/
sudo mv -f config.jsonc style.css /etc/xdg/waybar/
sudo rm -rf /etc/xdg/waybar/config
cd ~/.config/
mkdir waybar
cd ~/hyprland-config/waybar/
sudo mv -f scripts/ ~/.config/waybar/
chmod +x ~/.config/waybar/scripts/waybar-wttr.py
cd ~/Downloads/

### Enabling sddm ###

sudo systemctl enable sddm

GREEN='\033[0;32m'
printf "\n${GREEN} Now you can reboot!\n"
