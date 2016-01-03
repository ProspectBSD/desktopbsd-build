#!/bin/sh
#
# Copyright (c) 2011 GhostBSD
#
# See COPYING for licence terms.
#
# $GhostBSD$
# $Id: img.sh,v 1.6 monday 12/26/11 Eric Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH

GHOSTBSD_LABEL=`echo $GHOSTBSD_LABEL | tr '[:lower:]' '[:upper:]'`
cd ${BASEDIR} && tar -cpzf ${BASEDIR}/dist/etc.tgz etc

make_bios_img()
{
echo "==> making bios img"
echo "/dev/ufs/${GHOSTBSD_LABEL} / ufs ro,noatime 1 1" > ${BASEDIR}/etc/fstab
echo "proc /proc procfs rw 0 0" >> ${BASEDIR}/etc/fstab 
echo "linproc /compat/linux/proc linprocfs rw 0 0" >> ${BASEDIR}/etc/fstab
makefs -B little -o label=${GHOSTBSD_LABEL} ${IMGPATH} ${BASEDIR}
if [ $? -ne 0 ]; then
  echo "makefs failed"
  exit 1
fi

unit=`mdconfig -a -t vnode -f ${IMGPATH}`
if [ $? -ne 0 ]; then
  echo "mdconfig failed"
  exit 1
fi

gpart create -s BSD ${unit}
gpart bootcode -b ${BASEDIR}/boot/boot ${unit}
gpart add -t freebsd-ufs ${unit}
mdconfig -d -u ${unit}
echo "bios img done"
}

make_uefi_img()
{
echo "==> making uefi img"
echo "/dev/ufs/${GHOSTBSD_LABEL} / ufs ro,noatime 1 1" > ${BASEDIR}/etc/fstab
echo "proc /proc procfs rw 0 0" >> ${BASEDIR}/etc/fstab 
echo "linproc /compat/linux/proc linprocfs rw 0 0" >> ${BASEDIR}/etc/fstab

# Borrowed from freebsd release scripts
makefs -B little -o label=$GHOSTBSD_LABEL ${UEFI_IMGPATH}.part ${BASEDIR}
if [ $? -ne 0 ]; then
	echo "makefs for uefi failed"
	exit 1
fi

mkimg -s gpt -b ${BASEDIR}/boot/pmbr -p efi:=${BASEDIR}/boot/boot1.efifat -p freebsd-boot:=${BASEDIR}/boot/gptboot -p freebsd-ufs:=${UEFI_IMGPATH}.part -p freebsd-swap::1M -o ${UEFI_IMGPATH}
rm ${UEFI_IMGPATH}.part
echo "uefi img done"
}

make_checksums()
{
echo "==> making checksums"
cd /usr/obj/${ARCH}/${PACK_PROFILE}
md5 `echo ${IMGPATH}|cut -d / -f6`  >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${IMGPATH}|cut -d / -f6).md5
sha256 `echo ${IMGPATH}| cut -d / -f6` >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${IMGPATH}|cut -d / -f6).sha256

if [ "$ARCH" = "amd64" ]; then
    md5 `echo ${UEFI_IMGPATH}|cut -d / -f6`  >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${UEFI_IMGPATH}|cut -d / -f6).md5
    sha256 `echo ${UEFI_IMGPATH}| cut -d / -f6` >> /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${UEFI_IMGPATH}|cut -d / -f6).sha256
fi
cd -
echo "checksums done"
}

make_bios_img

if [ "${ARCH}" = "amd64" ]; then
    make_uefi_img
fi

make_checksums
