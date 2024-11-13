#!/usr/bin/bash

apt update -y -q
apt install libguestfs-tools -y -q

DISTRO="${DISTRO:-debian}"
case $DISTRO in
  debian)
    CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    CLOUD_IMAGE_FILE="debian-12-generic-amd64.qcow2"
    ;;
  *)
    echo "No Distro Set" >&2
    exit 1
    ;;
esac

CLOUD_IMAGE_FILE="${DOWNLOAD_FOLDER:-/var/lib/vz/template/iso/}$CLOUD_IMAGE_FILE"
CORES="${CORES:-1}"
MEMORY="${MEMORY:-2048}"
DISK_SIZE="${DISK_SIZE:-16G}"
TEMPLATE_ID="${TEMPLATE_ID:-9001}"

echo Distro "$DISTRO"
echo Cloud Image URL "$CLOUD_IMAGE_URL"
echo Cloud Image File "$CLOUD_IMAGE_FILE"
echo Core "$CORES"
echo Memory "$MEMORY"
echo Disk Size "$DISK_SIZE"
echo Template ID "$TEMPLATE_ID"

wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"

if [ ! -f "$CLOUD_IMAGE_FILE" ]; then
  echo "No Distro Set" >&2
  exit 1
fi

virt-customize -a "$CLOUD_IMAGE_FILE" --install qemu-guest-agent
qm create "$TEMPLATE_ID" --name "$TEMPLATE_NAME" --cores "$CORES" --memory "$MEMORY" --net0 virtio,bridge=vmbr0
qm importdisk "$TEMPLATE_ID" "$CLOUD_IMAGE_FILE" local-lvm
qm set "$TEMPLATE_ID" --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-"$TEMPLATE_ID"-disk-0
qm set "$TEMPLATE_ID" --boot c --bootdisk scsi0
qm set "$TEMPLATE_ID" --ide2 local-lvm:cloudinit
qm set "$TEMPLATE_ID" --agent 1
qm set "$TEMPLATE_ID" --machine q35
qm set "$TEMPLATE_ID" --serial0 socker --vga serial0
qm set "$TEMPLATE_ID" --ipconfig0 ip=dhcp
qm resize "$TEMPLATE_ID" scsi0 "$DISK_SIZE"
qm template "$TEMPLATE_ID"
