#!/usr/bin/env bash

SNIPPETS=/var/lib/vz/snippets
GITHUB_BASE=https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/


function create {
  NAME=$1
  IMAGE_URL=$2

  curl --create-dirs -O --output-dir /tmp/images "$IMAGE_URL"
  curl --create-dirs -O --output-dir "$SNIPPETS" "$GITHUB_BASE/$NAME"

  virt-customize -a "/tmp/images/$(basename $IMAGE_URL)" --install qemu-guest-agent

  qm destroy "$VMID"
  qm create "$VMID" --name "$NAME"
  qm set "$VMID" --cores 1
  qm set "$VMID" --memory 2048
  qm set "$VMID" --net0 virtio,bridge=vmbr0
  qm set "$VMID" --ipconfig0 ip=dhcp
  qm set "$VMID" --scsihw virtio-scsi-pci
  qm set "$VMID" --scsi0 local-lvm:0,import-from="$CLOUD_IMAGE_FILE",discard=on,ssd=1
  qm set "$VMID" --ide2 local-lvm:cloudinit
  qm set "$VMID" --boot order=scsi0
  qm set "$VMID" --agent 1
  qm set "$VMID" --machine q35
  qm set "$VMID" --serial0 socket --vga serial0
  qm set "$VMID" --cicustom "user=local:snippets/$USER_DATA"
  qm template "$VMID"
}

# Update Packages
apt update -y -q
apt install libguestfs-tools curl -y -q

TEMPLATES=(
  "debian,debian"
  "debian,debian-kubernetes"
)

IFS=','; for i in $TEMPLATES; do set -- $i;
  echo $1 $2
  case $1 in
  debian)
    url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    ;;
  esac
  create $2 $url
done

