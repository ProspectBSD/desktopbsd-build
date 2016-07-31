#!/bin/sh

# load fuse kernel module for all fuse* progs
grep -q "fuse_load" /boot/loader.conf
if [ $? -ne 0 ]; then
    echo 'fuse_load="YES"' >> /boot/loader.conf
fi 

if [ -e /usr/local/bin/ntfs-3g ]; then
    ln -s /usr/local/bin/ntfs-3g /sbin/mount_ntfs
fi