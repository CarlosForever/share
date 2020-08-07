#!/bin/bash
set -e

PKG_LIST="lvm2 cryptsetup grub efibootmgr nano firefox geany"
HOSTNAME="Magic-Box"
KEYMAP="us"
TIMEZONE="Europe/Amsterdam"
LANG="en_US.UTF-8"
CRYPTDEVNAME="pool-party"
VGNAME="sars_pool"

#set static sizes for lvm's to be calculated and used
VGNAME_SWAP_SIZE=1
VGNAME_VAR_SIZE=5
VGNAME_HOME_SIZE=5

#getting information for size calculations
raw_disk_size=$(lsblk -m --output SIZE -n -d /dev/sda)
disk_size="${raw_disk_size%%.*}"

pacman -S cryptsetup parted lvm2 nano

dd if=/dev/zero of=/dev/sda bs=1M count=100

parted /dev/sda mklabel msdos
parted -a optimal /dev/sda mkpart primary 100M 1100M
parted -a optimal /dev/sda mkpart primary 1100M 100%
parted /dev/sda set 1 boot on

cryptsetup luksFormat -c aes-xts-plain64 -s 512 /dev/sda2
cryptsetup luksOpen /dev/sda2 ${CRYPTDEVNAME}

pvcreate /dev/mapper/${CRYPTDEVNAME}
vgcreate ${VGNAME} /dev/mapper/${CRYPTDEVNAME}

#create individual logical lovumes
lvcreate -L $VGNAME_VAR_SIZE"G" -n swap ${VGNAME}
lvcreate -L $VGNAME_VAR_SIZE"G" -n var ${VGNAME}
lvcreate -L $VGNAME_HOME_SIZE"G" -n home ${VGNAME}
lvcreate -L 5G -n root ${VGNAME}

mkfs.ext4 -L boot /dev/sda1
mkfs.ext4 -L root /dev/mapper/${VGNAME}-root
mkswap /dev/mapper/${VGNAME}-swap
mkfs.ext4 -L var /dev/mapper/${VGNAME}-var
mkfs.ext4 -L home /dev/mapper/${VGNAME}-home

mount /dev/mapper/${VGNAME}-root /mnt
mount /dev/mapper/${VGNAME}-home /mnt/home
mount /dev/mapper/${VGNAME}-var /mnt/var
swapon /dev/mapper/${VGNAME}-swap

mount /dev/sda1 /mnt/boot

basestrap /mnt base base-devel runit elogind-runit linux linux-firmware
fstabgen -U /mnt >> /mnt/etc/fstab

artools-chroot /mnt
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime

hwclock --systohc

pacman -S nano
nano /etc/locale.gen
