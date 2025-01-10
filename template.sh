#!/usr/bin/env bash

VMID=9000
SNIPPETS=/var/lib/vz/snippets/
GITHUB_BASE=https://raw.githubusercontent.com/proxmox-kubernetes/templates/refs/heads/main/

function create {
  NAME=$1
  IMAGE_URL=$2
  IMAGE_FILE="/tmp/images/$(basename $IMAGE_URL)"

  echo "Name: $NAME"
  echo "URL: $IMAGE_URL"

  mkdir p "/tmp/images"
  curl -o "$IMAGE_FILE" -L "$IMAGE_URL"
  virt-customize -a "$IMAGE_FILE" --install qemu-guest-agent

  curl -o "$SNIPPETS/$NAME.yml" -L "$GITHUB_BASE/cloud-init/$NAME.yml"

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

TEMPLATES=(
  "debian https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  "ubuntu https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img"
)

for i in "${TEMPLATES[@]}"; do
  set -- $i
  ((VMID++))
  create $1 $2
done

