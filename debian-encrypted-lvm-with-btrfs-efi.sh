#!/bin/sh

# Set up constants.
CRYPT_DM_NAME="cryptlvm"
CRYPT_BLOCK_DEVICE="/dev/sda2"
LVM_VG_NAME="vg"
EFI_BLOCK_DEVICE="/dev/sda1"

# Unmount existing target installer was going to install to.
umount /target/boot/efi
umount /target

# Fail out of the script if any commands fail from this point forward.
set -e

# Install tools we need to set up the LUKS encrypted volume. (cryptsetup, etc.)
anna-install cryptsetup-udeb cdebconf-newt-entropy partman-crypto-dm

# Load dm_crypt, which will be needed to open the encrypted volume.
depmod -a
modprobe dm_crypt

# Setup encrypted volume.
cryptsetup --type luks1 -y -v luksFormat "$CRYPT_BLOCK_DEVICE"

# Open encrypted volume.
cryptsetup open "$CRYPT_BLOCK_DEVICE" "$CRYPT_DM_NAME"

# Create LVM physical volume, volume group, and logical volumes.
pvcreate "/dev/mapper/$CRYPT_DM_NAME"
vgcreate "$LVM_VG_NAME" "/dev/mapper/$CRYPT_DM_NAME"
lvcreate -L 8G "$LVM_VG_NAME" -n swap
lvcreate -l 100%FREE "$LVM_VG_NAME" -n root

# Setup Btrfs partition and swap.
mkfs.btrfs "/dev/$LVM_VG_NAME/root"
mkswap "/dev/$LVM_VG_NAME/swap"

# Mount Btrfs partition and set up subvolumes.
mount "/dev/$LVM_VG_NAME/root" /target
cd /target
btrfs subvol create @
btrfs subvol create @home
btrfs subvol create @snapshots
btrfs subvol create @log

cd /

# Unmount Btrfs partition, and remount the subvolumes in the correct mount points.
umount /target
mount "/dev/$LVM_VG_NAME/root" /target -o subvol=@
mkdir -p /target/home /target/var/log /target/.btrfs /target/boot/efi
mount "/dev/$LVM_VG_NAME/root" /target/home -o subvol=@home
mount "/dev/$LVM_VG_NAME/root" /target/var/log -o subvol=@log
mount "$EFI_BLOCK_DEVICE" /target/boot/efi

read -p "Install the system packages and GRUB now. The GRUB install should fail. Return here after it fails. Press any key to resume ..."

# Enable cryptodisk in GRUB, so GRUB install will work. 
echo 'GRUB_ENABLE_CRYPTODISK=y' >> /target/etc/default/grub

# Add cryptdevice, root, and rootflags to default kernel cmdline.
sed -i "s,GRUB_CMDLINE_LINUX=\"\(.*\)\",GRUB_CMDLINE_LINUX=\"\1 cryptdevice=$CRYPT_BLOCK_DEVICE:$CRYPT_DM_NAME root=/dev/$LVM_VG_NAME/root rootflags=subvol=@\"," /target/etc/default/grub

read -p "Repeat the 'Install GRUB' step. Then return to this script at the 'Finish the installation' step. Press any key to resume ..."

# Mount things for chroot.
mount --bind /dev /target/dev
mount --bind /proc /target/proc
mount --bind /sys /target/sys
mount --bind /run /target/run

# Chroot into the new system. Install LVM, cryptsetup, and snapper. Set up crypttab, fstab, and snapper.
chroot /target /bin/bash -c "
apt install lvm2 cryptsetup snapper btrfs-progs -y

CRYPT_DM_NAME=\"$CRYPT_DM_NAME\"
CRYPT_BLOCK_DEVICE=\"$CRYPT_BLOCK_DEVICE\"
LVM_VG_NAME=\"$LVM_VG_NAME\"
EFI_BLOCK_DEVICE=\"$EFI_BLOCK_DEVICE\"

echo \"$CRYPT_DM_NAME  $CRYPT_BLOCK_DEVICE   /etc/keys/root.key    luks,key-slot=1\" >> /etc/crypttab
echo \"/dev/mapper/$LVM_VG_NAME-root   /   btrfs   defaults,subvol=@   0   0\" >> /etc/fstab
echo \"/dev/mapper/$LVM_VG_NAME-root   /.btrfs   btrfs   defaults   0   0\" >> /etc/fstab
echo \"/dev/mapper/$LVM_VG_NAME-root   /.snapshots   btrfs   defaults,subvol=@snapshots   0   0\" >> /etc/fstab
echo \"/dev/mapper/$LVM_VG_NAME-root   /home   btrfs   defaults,subvol=@home  0   0\" >> /etc/fstab
echo \"/dev/mapper/$LVM_VG_NAME-root   /var/log   btrfs   defaults,subvol=@log   0   0\" >> /etc/fstab
echo \"/dev/mapper/$LVM_VG_NAME-swap   none   swap   defaults   0   0\" >> /etc/fstab
echo \"$EFI_BLOCK_DEVICE   /boot/efi   vfat   defaults   0   0\" >> /etc/fstab

snapper --no-dbus -c root create-config /
snapper --no-dbus -c home create-config /home
snapper --no-dbus -c log create-config /var/log

rm -rf /.snapshots
mkdir .snapshots

mount .snapshots

chmod 750 .snapshots

snapper --no-dbus -c root create --description initial
snapper --no-dbus -c home create --description initial
snapper --no-dbus -c log create --description initial"

# Make a keyfile and add it to the LUKS container so the encryption password will not have to be entered twice when the system boots. Update cryptsetup-initramfs so the keyfile will be copied into the initramfs when that is generated.
mkdir -m0700 /target/etc/keys
( umask 0077 && dd if=/dev/urandom bs=1 count=64 of=/target/etc/keys/root.key conv=fsync )
cryptsetup luksAddKey $CRYPT_BLOCK_DEVICE /target/etc/keys/root.key
echo "KEYFILE_PATTERN=\"/etc/keys/*.key\"" >> /target/etc/cryptsetup-initramfs/conf-hook
echo UMASK=0077 >> /target/etc/initramfs-tools/initramfs.conf

echo 'Finish the installation and reboot.'
