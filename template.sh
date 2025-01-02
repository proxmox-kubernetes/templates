#!/usr/bin/env bash

VMID=9000
SNIPPETS=/var/lib/vz/snippets/
GITHUB_BASE=https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/

function create {
  DISTRO=$1
  NAME=$2
  IMAGE_URL=$3
  IMAGE_FILE="/tmp/images/$(basename $IMAGE_URL)"

  echo "ID: $VMID"
  echo "Name: $NAME"
  echo "URL: $IMAGE_URL"

  if [ ! -f "$IMAGE_FILE" ]; then
    curl -s -o "$IMAGE_FILE" -L "$IMAGE_URL"
    virt-customize -a "$IMAGE_FILE" --install qemu-guest-agent
  fi

  curl -s -o "$SNIPPETS/$NAME.yml" -L "$GITHUB_BASE/$DISTRO/$NAME.yml"

  qm destroy "$VMID"
  qm create "$VMID" --name "$NAME"
  qm set "$VMID" --cores 1
  qm set "$VMID" --memory 2048
  qm set "$VMID" --net0 virtio,bridge=vmbr0
  qm set "$VMID" --ipconfig0 ip=dhcp
  qm set "$VMID" --scsihw virtio-scsi-pci
  qm set "$VMID" --scsi0 local-lvm:0,import-from="$IMAGE_FILE",discard=on,ssd=1
  qm set "$VMID" --ide2 local-lvm:cloudinit
  qm set "$VMID" --boot order=scsi0
  qm set "$VMID" --agent 1
  qm set "$VMID" --machine q35
  qm set "$VMID" --serial0 socket --vga serial0
  qm set "$VMID" --cicustom "user=local:snippets/$NAME.yml"
  qm template "$VMID"
}

# Update Packages
apt update -y -q &> /dev/null
apt install libguestfs-tools curl -y -q &> /dev/null

TEMPLATES=(
  "debian debian"
  "debian debian-kubernetes"
  "ubuntu ubuntu"
  "ubuntu ubuntu-kubernetes"
)

declare -A urls=(
  [debian]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  [ubuntu]="https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img"
)

rm -rf "$SNIPPETS" 
mkdir "$SNIPPETS"

for i in "${TEMPLATES[@]}"; do
  set -- $i
  ((VMID++))
  create $1 $2 ${urls[$1]}
done

