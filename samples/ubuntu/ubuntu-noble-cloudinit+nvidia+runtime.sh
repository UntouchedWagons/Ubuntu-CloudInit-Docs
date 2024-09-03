#! /bin/bash

VMID=8202
STORAGE=local-zfs

set -x
rm -f noble-server-cloudimg-amd64+nivida.img
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O noble-server-cloudimg-amd64+nivida.img
qemu-img resize noble-server-cloudimg-amd64.img 8G
sudo qm destroy $VMID
sudo qm create $VMID --name "ubuntu-noble-template-nvidia-runtime" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --cores 1 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
sudo qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | sudo tee /var/lib/vz/snippets/ubuntu-noble-runtime.yaml
#cloud-config
runcmd:
    - curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    - curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    - apt-get update
    - apt-get install -y qemu-guest-agent nvidia-dkms-550-server nvidia-utils-550-server nvidia-container-runtime
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/ubuntu-noble-runtime.yaml"
sudo qm set $VMID --tags ubuntu-template,noble,cloudinit,nvidia
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID
