#! /bin/bash

set -xe

VMID="${VMID:-8202}"
STORAGE="${STORAGE:-local-zfs}"

IMG="noble-server-cloudimg-amd64.img"
BASE_URL="https://cloud-images.ubuntu.com/noble/current"
EXPECTED_SHA=$(wget -qO- "$BASE_URL/SHA256SUMS" | awk '/'$IMG'/{print $1}')

download() {
    wget -q "$BASE_URL/$IMG"
}

verify() {
    sha256sum "$IMG" | awk '{print $1}'
}

[ ! -f "$IMG" ] && download

ACTUAL_SHA=$(verify)

if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    rm -f "$IMG"
    download
    ACTUAL_SHA=$(verify)
    [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ] && exit 1
fi

rm -f noble-server-cloudimg-amd64-resized.img
cp noble-server-cloudimg-amd64.img noble-server-cloudimg-amd64-resized.img
qemu-img resize noble-server-cloudimg-amd64-resized.img 8G

sudo qm destroy $VMID || true
sudo qm create $VMID --name "ubuntu-noble-template-nvidia-runtime" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0
sudo qm importdisk $VMID noble-server-cloudimg-amd64-resized.img $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

mkdir /var/lib/vz/snippets
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
