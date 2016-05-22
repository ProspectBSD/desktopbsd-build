#!/bin/sh
#
# Copyright (c) 2011 GhostBSD
#
# See COPYING for licence terms.
#
# $GhostBSD$
# $Id: iso.sh,v 1.7 Thu Dec 15 18:08:31 AST 2011 Eric

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi


echo "#### Building bootable ISO images for ${ARCH} ####"

# Creates etc/fstab to avoid messages about missing it
# needed only for hybrid iso but I leave it here
if [ ! -e ${BASEDIR}/etc/fstab ] ; then
    touch ${BASEDIR}/etc/fstab
fi

cd ${BASEDIR} && tar -cpzf ${BASEDIR}/dist/etc.tgz etc

make_standard_iso()
{
echo "==> Making standard iso"
GHOSTBSD_LABEL=`echo $GHOSTBSD_LABEL | tr '[:lower:]' '[:upper:]'`
echo "/dev/iso9660/$GHOSTBSD_LABEL / cd9660 ro 0 0" > $BASEDIR/etc/fstab
echo "### Running makefs to create ISO ###"
bootable="-o bootimage=i386;${BASEDIR}/boot/cdboot -o no-emul-boot"
makefs -t cd9660 $bootable -o rockridge -o label=${GHOSTBSD_LABEL} ${ISOPATH} ${BASEDIR}
echo "standard iso done"
}

make_grub_iso()
{
GHOSTBSD_LABEL=`echo $GHOSTBSD_LABEL | tr '[:lower:]' '[:upper:]'`
# Reference for hybrid DVD/USB image
# Use GRUB to create the hybrid DVD/USB image
echo "==> Creating hybrid iso"
grub-mkrescue -o ${ISOPATH} ${BASEDIR} -- -volid ${GHOSTBSD_LABEL}
if [ $? -ne 0 ] ; then
	echo "Failed running grub-mkrescue"
	exit 1
fi
echo "hybrid iso done"
}

make_standard_uefi_iso()
{
echo "==> Making uefi iso"
GHOSTBSD_LABEL=`echo $GHOSTBSD_LABEL | tr '[:lower:]' '[:upper:]'`
echo "/dev/iso9660/$GHOSTBSD_LABEL / cd9660 ro 0 0" > $BASEDIR/etc/fstab

# Borrowed from freebsd release scripts
# Make EFI system partition (should be done with makefs in the future)
dd if=/dev/zero of=efiboot.img bs=4k count=150
device=`mdconfig -a -t vnode -f efiboot.img`
newfs_msdos -F 12 -m 0xf8 /dev/$device
mkdir -p efi
mount -t msdosfs /dev/$device efi
mkdir -p efi/efi/boot
cp ${BASEDIR}/boot/loader.efi efi/efi/boot/bootx64.efi
umount efi
rmdir efi
mdconfig -d -u $device

bootable="-o bootimage=i386;efiboot.img -o no-emul-boot"
makefs -t cd9660 $bootable -o rockridge -o label=${GHOSTBSD_LABEL} ${UEFI_ISOPATH} ${BASEDIR}
rm -f efiboot.img
echo "uefi iso done"
}

echo "### ISO created ###"

# Make md5 and sha256 for iso
make_checksums()
{
echo "==> Making checksums"
cd /usr/obj/${ARCH}/${PACK_PROFILE}
md5 `echo ${ISOPATH}|cut -d / -f6`  >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${ISOPATH}|cut -d / -f6).md5
sha256 `echo ${ISOPATH}| cut -d / -f6` >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${ISOPATH}|cut -d / -f6).sha256

if [ "$ARCH" = "amd64" ]; then
    md5 `echo ${UEFI_ISOPATH}|cut -d / -f6`  >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${UEFI_ISOPATH}|cut -d / -f6).md5
    sha256 `echo ${UEFI_ISOPATH}| cut -d / -f6` >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${UEFI_ISOPATH}|cut -d / -f6).sha256
fi
cd -
echo "checksums done"
}


make_standard_iso
#make_grub_iso
if [ "${ARCH}" = "amd64" ]; then
    make_standard_uefi_iso
fi
make_checksums


set -e
cd ${LOCALDIR}
