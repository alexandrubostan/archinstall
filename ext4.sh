#!/bin/bash

set -eo pipefail

EFI='/dev/nvme0n1p1'
ROOT='/dev/nvme0n1p4'
DRIVE='/dev/nvme0n1'
EFIPART=1

ext4_fs () {
    mkfs.ext4 "$ROOT"
    mount "$ROOT" /mnt
    mount --mkdir "$EFI" /mnt/efi
}

ext4_luks_fs () {
    cryptsetup luksFormat "$ROOT"
    cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open "$ROOT" root
    mkfs.ext4 /dev/mapper/root
    mount /dev/mapper/root /mnt
    mount --mkdir "$EFI" /mnt/efi
}

ext4_fs
#ext4_luks_fs

pacstrap -K /mnt base linux linux-firmware vim sudo amd-ucode networkmanager

echo '%wheel      ALL=(ALL:ALL) NOPASSWD: ALL' | tee -a /mnt/etc/sudoers > /dev/null

sed -e '/en_US.UTF-8/s/^#*//' -i /mnt/etc/locale.gen
sed -e '/ro_RO.UTF-8/s/^#*//' -i /mnt/etc/locale.gen
sed -e '/ParallelDownloads/s/^#*//' -i /mnt/etc/pacman.conf

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt locale-gen

echo 'LANG=en_US.UTF-8' | tee /mnt/etc/locale.conf > /dev/null
echo 'ArchBox' | tee /mnt/etc/hostname > /dev/null

mkdir -p /mnt/etc/cmdline.d
echo 'rootflags=defaults,noatime rw quiet' | tee /mnt/etc/cmdline.d/root.conf > /dev/null

tee /mnt/etc/mkinitcpio.d/linux.preset > /dev/null << EOF
# mkinitcpio preset file for the 'linux' package

#ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
default_uki="/efi/EFI/Linux/arch-linux.efi"
default_options="--splash=/usr/share/systemd/bootctl/splash-arch.bmp"
EOF

tee /mnt/etc/mkinitcpio.conf > /dev/null << EOF
MODULES=()

BINARIES=()

FILES=()

HOOKS=(systemd autodetect microcode modconf keyboard block filesystems fsck)
#HOOKS=(systemd autodetect microcode modconf keyboard block sd-encrypt filesystems fsck)
EOF

efistub () {
    mkdir -p /mnt/efi/EFI/Linux
    arch-chroot /mnt mkinitcpio -p linux
    
    efibootmgr --create --disk "$DRIVE" --part "$EFIPART" --label "Arch Linux" --loader 'EFI/Linux/arch-linux.efi' --unicode
}
systemd_boot () {
    arch-chroot /mnt bootctl install
    arch-chroot /mnt mkinitcpio -p linux
}

systemd_boot
#efistub

install_kde () {
    arch-chroot /mnt pacman -S --needed \
    breeze-gtk \
    drkonqi \
    kde-gtk-config \
    kdeplasma-addons \
    kgamma \
    kinfocenter \
    kscreen \
    ksshaskpass \
    kwallet-pam \
    kwrited \
    plasma-desktop \
    plasma-disks \
    plasma-firewall \
    plasma-nm \
    plasma-pa \
    plasma-systemmonitor \
    powerdevil \
    power-profiles-daemon \
    sddm-kcm \
    xdg-desktop-portal-kde \
    xdg-desktop-portal-gtk \
    ufw \
    kitty \
    dolphin \
    kate \
    filelight \
    ark \
    p7zip
    
    systemctl enable sddm.service --root=/mnt
}

install_gnome () {
    arch-chroot /mnt pacman -S --needed \
    baobab \
    gdm \
    gnome-calendar \
    gnome-characters \
    gnome-clocks \
    gnome-console \
    gnome-control-center \
    gnome-disk-utility \
    gnome-font-viewer \
    gnome-keyring \
    gnome-logs \
    gnome-session \
    gnome-settings-daemon \
    gnome-shell \
    gnome-tweaks \
    gnome-system-monitor \
    gnome-text-editor \
    grilo-plugins \
    gvfs \
    gvfs-mtp \
    loupe \
    malcontent \
    nautilus \
    sushi \
    tecla \
    xdg-desktop-portal-gnome \
    xdg-user-dirs-gtk
    
    systemctl enable gdm.service --root=/mnt
}

install_apps () {
    arch-chroot /mnt pacman -S --needed \
    firefox \
    pipewire-alsa \
    flatpak \
    htop \
    nvtop \
    calc
}

install_kde
#install_gnome
install_apps

systemctl enable fstrim.timer --root=/mnt
systemctl enable NetworkManager.service --root=/mnt

arch-chroot /mnt passwd
read -r -p "Enter username: " user
arch-chroot /mnt useradd -m -G wheel "$user"
arch-chroot /mnt passwd "$user"
