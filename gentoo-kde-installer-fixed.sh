#!/bin/bash
set -e

# --- CONFIG ---
DISK="/dev/sda"
HOSTNAME="gentoo"
LOCALE="en_US.UTF-8"
TIMEZONE="Canada/Vancouver"
ROOT_PASS="Root"
USER_NAME="user"
USER_PASS="User"
STAGE3_BASE="https://gentoo.osuosl.org/releases/amd64/autobuilds"
PORTAGE_SNAPSHOT="https://distfiles.gentoo.org/snapshots/portage-latest.tar.xz"
MAKE_CONF_OPTIONS='COMMON_FLAGS="-march=native -O2 -pipe"
MAKEOPTS="-j$(nproc)"
USE="X kde plasma wayland -gnome systemd elogind"
'

# --- PARTITION & FORMAT ---
sgdisk -Z ${DISK}
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI ${DISK}
sgdisk -n 2:0:0     -t 2:8300 -c 2:ROOT ${DISK}
mkfs.vfat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

# --- MOUNT ---
mount ${DISK}2 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount ${DISK}1 /mnt/gentoo/boot/efi

# --- STAGE3 ---
cd /mnt/gentoo
STAGE3_FILE=$(curl -s ${STAGE3_BASE}/latest-stage3-amd64-openrc.txt | grep -v '^#' | awk 'NR==1 {print $1}')
wget ${STAGE3_BASE}/${STAGE3_FILE}
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

# --- PORTAGE ---
wget ${PORTAGE_SNAPSHOT}
tar -xpf portage-latest.tar.xz -C /mnt/gentoo/usr

# --- CHROOT PREP ---
cp -L /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# --- MAKE.CONF ---
cat <<EOF > /mnt/gentoo/etc/portage/make.conf
${MAKE_CONF_OPTIONS}
EOF

# --- CHROOT ---
cat <<'EOC' | chroot /mnt/gentoo /bin/bash

env-update && source /etc/profile

# Timezone & locale
echo "${TIMEZONE}" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "${LOCALE} UTF-8" > /etc/locale.gen
locale-gen
eselect locale set ${LOCALE}
env-update && source /etc/profile

# Hostname & networking
echo "${HOSTNAME}" > /etc/hostname
echo "127.0.0.1 ${HOSTNAME} localhost" >> /etc/hosts
emerge --noreplace net-misc/dhcpcd
rc-update add dhcpcd default

# Kernel
emerge sys-kernel/gentoo-sources sys-kernel/genkernel
genkernel all

# FSTAB
echo -e "$(blkid -s UUID -o value ${DISK}2)\t/\text4\tdefaults\t0 1" > /etc/fstab
echo -e "$(blkid -s UUID -o value ${DISK}1)\t/boot/efi\tvfat\tdefaults\t0 2" >> /etc/fstab

# Bootloader
emerge sys-boot/grub:2 efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=gentoo
grub-mkconfig -o /boot/grub/grub.cfg

# Users
echo "root:${ROOT_PASS}" | chpasswd
useradd -m -G users,wheel,audio,video -s /bin/bash ${USER_NAME}
echo "${USER_NAME}:${USER_PASS}" | chpasswd

# Enable sudo
emerge app-admin/sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# KDE Plasma + Display Manager
emerge --noreplace x11-base/xorg-drivers x11-base/xorg-server kde-plasma/plasma-meta kde-apps/kdecore-meta sddm
rc-update add sddm default
echo "DISPLAYMANAGER=\"sddm\"" > /etc/conf.d/xdm
rc-update add xdm default

# Done
exit
EOC

echo "✅ Installation complete. Rebooting in 10 seconds..."
sleep 10
reboot
