#! /bin/bash

set -xe

VMID="${VMID:-8000}"
STORAGE="${STORAGE:-local-zfs}"

IMG="debian-13-generic-amd64.qcow2"
BASE_URL="https://cloud.debian.org/images/cloud/trixie/latest"
EXPECTED_SHA=$(wget -qO- "$BASE_URL/SHA512SUMS" | awk '/'$IMG'/{print $1}')

download() {
    wget -q "$BASE_URL/$IMG"
}

verify() {
    sha512sum "$IMG" | awk '{print $1}'
}

[ ! -f "$IMG" ] && download

ACTUAL_SHA=$(verify)

if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    rm -f "$IMG"
    download
    ACTUAL_SHA=$(verify)
    [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ] && exit 1
fi

rm -f debian-13-generic-amd64-resized.qcow2
cp debian-13-generic-amd64.qcow2 debian-13-generic-amd64-resized.qcow2
qemu-img resize debian-13-generic-amd64-resized.qcow2 8G

sudo qm destroy $VMID || true
sudo qm create $VMID --name "debian-13-template-nvidia" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu x86-64-v2-AES --cores 1 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
sudo qm importdisk $VMID debian-13-generic-amd64-resized.qcow2 $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

if [ ! -d "/var/lib/vz/snippets" ]; then
  mkdir -p "/var/lib/vz/snippets"
fi

cat << EOF | sudo tee /var/lib/vz/snippets/debian-13-nvidia.yaml
#cloud-config
runcmd:
    - |
      sed -i 's/^Components: main$/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
    - apt-get install -y gpg
    - curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    - curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/debian-13-nvidia.yaml"
sudo qm set $VMID --tags debian-template,debian-13,cloudinit,nvidia
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp,ip6=dhcp
sudo qm template $VMID

# Requires manual installation of `nvidia-driver firmware-misc-nonfree nvidia-smi nvidia-container-runtime` it seems`