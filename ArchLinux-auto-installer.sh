#!/bin/bash
set -e

# --- CONFIGURATION ----
DISK="/dev/sda"
HOSTNAME="arch"
ROOT_PASSWORD="changeme"

echo "[*] Wiping $DISK and creating partitions"
sgdisk -Z "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI "$DISK"
sgdisk -n 2:0:0     -t 2:8300 -c 2:ROOT "$DISK"

echo "[*] Formatting partitions."
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

echo "[*] Mounting partitions"
mount ${DISK}2 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot

echo "[*] Installing base system with networking and SSH"
pacstrap /mnt base linux linux-firmware openssh systemd-networkd systemd-resolved vim sudo

echo "[*] Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Chrooting and configuring system"
arch-chroot /mnt /bin/bash <<EOF
# Timezone and locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname and hosts
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Enable services
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable sshd

# Configure network with static DNS
cat <<NET > /etc/systemd/network/20-wired.network
[Match]
Name=en*

[Network]
DHCP=yes

[DHCP]
UseDNS=false

[DNS]
DNS=8.8.8.8
NET

# Static DNS entry
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Colorful Bash prompt for root (yellow)
echo 'PS1="\[\e[1;33m\]\u@\h \W \$\[\e[0m\] "' >> /root/.bashrc

# Install GRUB (UEFI)
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "[*] Unmounting and rebooting"
umount -R /mnt
reboot
