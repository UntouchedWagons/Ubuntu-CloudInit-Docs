#! /bin/bash

VMID=8001
STORAGE=local-zfs

set -x
rm -f debian-12-generic-amd64+docker.qcow2
wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 -O debian-12-generic-amd64+docker.qcow2
qemu-img resize debian-12-generic-amd64+docker.qcow2 8G
sudo qm destroy $VMID
sudo qm create $VMID --name "debian-12-template-dcoker" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu x86-64-v2-AES --cores 1 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
sudo qm importdisk $VMID debian-12-generic-amd64+docker.qcow2 $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --ide2 $STORAGE:cloudinit

cat << EOF | sudo tee /mnt/pve/remote-nfs/snippets/debian-12-docker.yaml
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent gnupg
    - install -m 0755 -d /etc/apt/keyrings
    - curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    - chmod a+r /etc/apt/keyrings/docker.gpg
    - echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    - apt-get update
    - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

sudo qm set $VMID --cicustom "vendor=remote-zfs:snippets/debian-12-docker.yaml"
sudo qm set $VMID --tags debian-template,debian-12,cloudinit,docker
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID
