#!/bin/bash

if [ "$(id -u)" = 0 ]; then
    echo "######################################################################"
    echo "This script should NOT be run as root user as it may create unexpected"
    echo " problems and you may have to reinstall Arch. So run this script as a"
    echo "  normal user. You will be asked for a sudo password when necessary"
    echo "######################################################################"
    exit 1
fi

read -p "Enter your Full Name: " fn
if [ -n "$fn" ]; then
    sudo chfn -f "$fn" "$(whoami)"
else
    echo ""
fi

sudo cp pacman.conf /etc/
sudo rm -rf /etc/pacman.d/hooks/
sudo mkdir /etc/pacman.d/hooks/
sudo cp gutenprint.hook /etc/pacman.d/hooks/
sudo cp 30-touchpad.conf /etc/X11/xorg.conf.d/

echo ""
read -r -p "Do you want to install Reflector? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -Syu --needed --noconfirm reflector
    echo ""
    echo "It will take time to fetch the server/mirrors so please wait"
    sudo reflector --save /etc/pacman.d/mirrorlist -p https -c 'Netherlands,United States, ' -l 10 --sort rate
    #Change location as per your need
fi

echo ""
sudo pacman -Syu --needed --noconfirm pacman-contrib
if [ "$(pactree -r linux)" ]; then
    sudo pacman -S --needed --noconfirm linux-headers
fi

if [ "$(pactree -r linux-zen)" ]; then
    sudo pacman -S --needed --noconfirm linux-zen-headers
fi

if [ "$(pactree -r yay-bin)" ]; then
    echo ""
    echo "Yay is already installed"
else
    git clone https://aur.archlinux.org/yay-bin.git --depth=1
    cd yay-bin
    yes | makepkg -si
    cd ..
    rm -rf yay-bin
fi

yay -S --answerclean A --answerdiff N --removemake --cleanafter --save

echo ""
read -r -p "Do you want to install Intel drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel #Intel
fi

echo ""
read -r -p "Do you want to install AMD/ATI drivers? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm mesa xf86-video-amdgpu xf86-video-ati libva-mesa-driver vulkan-radeon #AMD/ATI
fi

echo ""
read -r -p "Do you want to install Nvidia drivers(Maxwell+)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils nvidia-settings nvidia-prime opencl-nvidia switcheroo-control #NVIDIA
    sudo cp nvidia.conf /etc/modprobe.d/
    sudo sed -i 's/MODULES=\(.*\)/MODULES=\(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
    sudo systemctl enable nvidia-persistenced nvidia-hibernate nvidia-powerd nvidia-resume nvidia-suspend switcheroo-control
fi

echo ""
sudo pacman -S --needed --noconfirm - <tpkg
sudo systemctl enable --now ufw
sudo systemctl enable --now cups
sudo systemctl disable systemd-resolved.service
sudo systemctl enable sshd avahi-daemon power-profiles-daemon
sudo cp smb.conf /etc/samba/
echo -e "netbios name = $(hostname)\n\n" | sudo tee -a /etc/samba/smb.conf > /dev/null
echo ""
sudo smbpasswd -a $(whoami)
echo ""
sudo systemctl enable smb nmb
sudo cp kdeconnect /etc/ufw/applications.d/
sudo cupsctl
sudo ufw enable
sudo ufw allow IPP
sudo ufw allow CIFS
sudo ufw allow SSH
sudo ufw app update "KDE Connect"
sudo ufw allow "KDE Connect"
sudo cp /usr/share/doc/avahi/ssh.service /etc/avahi/services/
chsh -s /usr/bin/fish
sudo chsh -s /usr/bin/fish
pipx ensurepath
echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$(hostname)\n\n# The following lines are desirable for IPv6 capable hosts\n::1     localhost ip6-localhost ip6-loopback\nff02::1 ip6-allnodes\nff02::2 ip6-allrouters" | sudo tee /etc/hosts > /dev/null
#register-python-argcomplete --shell fish pipx >~/.config/fish/completions/pipx.fish

echo ""
read -r -p "Do you want to create a Samba Shared folder? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo cp smb.conf /etc/samba/
    echo -e "netbios name = $(hostname)\n\n" | sudo tee -a /etc/samba/smb.conf > /dev/null
    echo -e "[Samba Share]\ncomment = Samba Share\npath = /home/$(whoami)/Samba Share\nwritable = yes\nbrowsable = yes\nguest ok = no" | sudo tee -a /etc/samba/smb.conf > /dev/null
    rm -rf ~/Samba\ Share
    mkdir ~/Samba\ Share
    sudo systemctl restart smb nmb
fi

#sudo sed -i 's/Logo=1/Logo=0/' /etc/libreoffice/sofficerc

echo -e "VISUAL=nvim\nEDITOR=nvim" | sudo tee /etc/environment > /dev/null
grep -qF "set number" /etc/xdg/nvim/sysinit.vim || echo "set number" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null
grep -qF "set wrap!" /etc/xdg/nvim/sysinit.vim || echo "set wrap!" | sudo tee -a /etc/xdg/nvim/sysinit.vim > /dev/null

echo ""
echo "Installing KDE..."
echo ""
sudo pacman -S --needed --noconfirm - < kde
sudo pacman -Rscn --noconfirm krdp

sudo rm -rf /etc/sddm.conf.d/
sudo mkdir /etc/sddm.conf.d/
sudo cp kde_settings.conf /etc/sddm.conf.d/
sudo systemctl enable sddm
echo -e "[General]\nRememberOpenedTabs=false" | tee ~/.config/dolphinrc > /dev/null
echo -e "[Keyboard]\nNumLock=0" | tee ~/.config/kcminputrc > /dev/null
echo ""
read -r -p "Do you want to Touchpad configuration? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    touchpad_id=$(sudo libinput list-devices | grep "Touchpad" | awk '{print substr($0, 19)}')
    vendor_id=$(echo $touchpad_id | awk '{print substr($2, 1, 4)}')
    product_id=$(echo $touchpad_id | awk '{print substr($2, 6, 9)}')
    vendor_id_dec=$(printf "%d" 0x$vendor_id)
    product_id_dec=$(printf "%d" 0x$product_id)
    echo -e "[Keyboard]\nNumLock=0" | tee ~/.config/kcminputrc > /dev/null
    echo -e "\n[Libinput][$vendor_id_dec][$product_id_dec][$touchpad_id]\nNaturalScroll=true" | tee -a ~/.config/kcminputrc > /dev/null
fi

echo ""
read -r -p "Do you want to configure git? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    read -p "Enter your Git name: " git_name
    read -p "Enter your Git email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    ssh-keygen -C "$git_email"
    git config --global gpg.format ssh
    git config --global user.signingkey /home/$(whoami)/.ssh/id_ed25519.pub
    git config --global commit.gpgsign true
fi

echo ""
read -r -p "Do you want to install Firefox? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm firefox
fi

echo ""
read -r -p "Do you want to install Chromium? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm chromium
fi

echo ""
read -r -p "Do you want Bluetooth Service? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm bluez bluez-utils
    sudo systemctl enable bluetooth
fi

echo ""
read -r -p "Do you want to install HPLIP (Driver for HP printers)? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm hplip
    hp-plugin -i
fi

echo ""
read -r -p "Do you want to install Code-OSS? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm code
    echo ""
    read -r -p "Do you want to install proprietary VSCode marketplace? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        yay -S --needed --noconfirm code-marketplace
    fi
fi

echo ""
read -r -p "Do you want to install Telegram? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo pacman -S --needed --noconfirm telegram-desktop
fi

echo ""
read -r -p "Do you want to install Cloudflare Warp? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    wget -q -nc --show-progress https://github.com/ayu2805/cwi/releases/download/cloudflare-warp-install/cloudflare-warp-install && bash cloudflare-warp-install && rm cloudflare-warp-install
    warp-cli generate-completions fish | sudo tee /etc/fish/completions/warp-cli.fish > /dev/null
    echo ""
    echo "Waiting for 5 seconds..."
    sleep 5
fi

cp QtProject.conf ~/.config/
echo ""
echo "You can now reboot your system"
