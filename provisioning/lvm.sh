#!/bin/bash -eu
lshw -C DISK

partprobe -s

# https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script
# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can 
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "default" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sdf
  d # Delete any pre-existing partitions
  g # create a new empty GPT partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
    # default - use all available secors on the disk
  t # Change partition type to...
 31 # Linux LVM
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

# Inform kernel about partition table changes so a reboot can be avoided
partprobe -s

pvcreate /dev/sdf1
pvdisplay

vgcreate vg_hostpath_provisioner /dev/sdf1
vgdisplay

lvcreate -n lv_hostpath_provisioner -l 100%VG vg_hostpath_provisioner
lvdisplay

mkfs.ext4 /dev/vg_hostpath_provisioner/lv_hostpath_provisioner

lsblk

mkdir -p /mnt/k8s/hostpath_provisioner

echo "/dev/vg_hostpath_provisioner/lv_hostpath_provisioner  /mnt/k8s/hostpath_provisioner  ext4  defaults  0 2" >> /etc/fstab
# mount all devices listed in fstab
mount --all
