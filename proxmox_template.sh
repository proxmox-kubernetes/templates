#!/usr/bin/bash


DISTRO="${DISTRO:-debian}"
case $DISTRO in
debian)
  CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  CLOUD_IMAGE_FILE="/tmp/debian-12-generic-amd64.qcow2"
  TEMPLATE_NAME="debian-12-cloud"
  VMID=9001
  ;;
*)
  echo "No Distro Picked" >&2
  exit 1
  ;;
esac

# Update Packages
apt update -y -q
apt install libguestfs-tools -y -q

# Download Cloud Image and Install qemu-guest-agent
wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
virt-customize -a "$CLOUD_IMAGE_FILE" --install qemu-guest-agent

# Create VM
qm destroy "$VMID"
qm create "$VMID" --name "$TEMPLATE_NAME"

# Set Resources
qm set "$VMID" --cores 1
qm set "$VMID" --memory 2048

# Setup Networking
qm set "$VMID" --net0 virtio,bridge=vmbr0
qm set "$VMID" --ipconfig0 ip=dhcp

# Configure Drives
qm set "$VMID" --scsihw virtio-scsi-pci
qm set "$VMID" --scsi0 local-lvm:0,import-from="$CLOUD_IMAGE_FILE",discard=on,ssd=1
qm set "$VMID" --ide2 local-lvm:cloudinit
qm set "$VMID" --boot order=scsi0
qm resize "$VMID" scsi0 "$DISK_SIZE"

# Settings
qm set "$VMID" --agent 1
qm set "$VMID" --machine q35
qm set "$VMID" --serial0 socket --vga serial0

# Setup Cloud Init Configs
SNIPPETS=/var/lib/vz/snippets
wget -O "$SNIPPETS"/user-config.yml https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/user-config.yml
# wget -O "$SNIPPETS"/meta-config.yml https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/meta-config.yml
# wget -O "$SNIPPETS"/network-config.yml https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/network-config.yml
# qm set "$VMID" --cicustom "user=local:snippets/user-config.yml,meta=local:snippets/meta-config.yml,network=local:snippets/network-config.yml"
qm set "$VMID" --cicustom "user=local:snippets/user-config.yml"

# Make Template
qm template "$VMID"

# Clean up
rm $CLOUD_IMAGE_FILE
