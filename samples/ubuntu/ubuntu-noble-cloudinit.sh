#!/bin/bash -u

VMID=999
STORAGE=local-zfs

set -x
rm -f noble-server-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qemu-img resize noble-server-cloudimg-amd64.img 256G
sudo qm destroy $VMID
sudo qm create $VMID --name "ubuntu-noble-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --cores 1 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1 \
    --net1 virtio,bridge=vmbr1,mtu=1
sudo qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | sudo tee /var/lib/vz/snippets/ubuntu.yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
    - qemu-guest-agent
runcmd:
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/ubuntu.yaml"
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm set $VMID --ipconfig1 ip=dhcp
sudo qm template $VMID
