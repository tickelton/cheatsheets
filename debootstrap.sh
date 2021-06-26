#!/bin/bash

set -e

# Creates a bootable disk image using debootstrap and the Extlinux bootloader
# Requires: debootstrap, extlinux, parted, e2fsprogs


DISK_IMAGE=disk.img
ROOT_UUID=ebf0dc0a-c0f7-4afc-8b5c-fded24a996c6
DATA_UUID=c1b9d5a2-f162-11cf-9ece-0020afc76f16
ROOT_DIR=root
DATA_DIR=data

# create an empty file with a size of 2GB
dd if=/dev/zero of=${DISK_IMAGE} bs=1024 count=1 seek=2048k

# create a partition table with 2 partitions in the image file
parted  -s ${DISK_IMAGE} mktable msdos mkpart primary  ext3 1m 1g mkpart primary  ext3  1g 2g  toggle 1 boot

# bootstrap a minimal debian system into $ROOT_DIR
mkdir ${ROOT_DIR}
debootstrap --arch=amd64 --components=main,contrib,non-free --include=linux-image-amd64 --variant=minbase buster ${ROOT_DIR}/ http://ftp.de.debian.org/debian

# create the bootloader configuration
mkdir -p ${ROOT_DIR}/boot/extlinux
cat > ${ROOT_DIR}/boot/extlinux/extlinux.conf <<EOF
DEFAULT linux
 SAY Now booting the kernel from SYSLINUX...
LABEL linux
 KERNEL /boot/vmlinuz-4.19.0-17-amd64
 APPEND ro root=UUID=${ROOT_UUID} initrd=/boot/initrd.img-4.19.0-17-amd64 console=tty0 console=ttyS0,115200n8
EOF

# create a filesystem from $ROOT_DIR and write it to the disk image
mke2fs -F -d ${ROOT_DIR}/ -E offset=1048576 -j -L FS_ROOT -U ${ROOT_UUID} ${DISK_IMAGE} 975871k

# create the filesystem for the second partition
mkdir ${DATA_DIR}
echo "foobar" > ${DATA_DIR}/foo
mke2fs  -F -d ${DATA_DIR}/ -E offset=1000341504 -j -L FS_DATA -U ${DATA_UUID} ${DISK_IMAGE} 1120255k

# write the MBR to the disk image
dd if=/usr/lib/EXTLINUX/mbr.bin of=${DISK_IMAGE} conv=notrunc

# install the Extlinux bootloader into the first partition
DEV=`losetup --show -P -f ${DISK_IMAGE}`
mkdir mnt
mount ${DEV}p1 mnt/
extlinux --install mnt/boot/extlinux/
sleep 1
umount mnt
losetup  -d $DEV

# start the image in qemu
qemu-system-x86_64 -m 1024 -nographic -drive file=${DISK_IMAGE},format=raw
