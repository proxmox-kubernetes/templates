#!/usr/bin/bash


DISTRO="${DISTRO:-debian}"
CORES="${CORES:-1}"
MEMORY="${MEMORY:-2048}"
DISK_SIZE="${DISK_SIZE:-16G}"
TEMPLATE_ID="${TEMPLATE_ID:-9001}"
CLOUD_INIT_USER_FILE="https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/user-data.yml"
USER_DATA=/var/lib/vz/snippets/user-data.yaml

case $DISTRO in
debian)
  CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  CLOUD_IMAGE_FILE="debian-12-generic-amd64.qcow2"
  TEMPLATE_NAME="debian-12-cloud"
  ;;
*)
  echo "No Distro Set" >&2
  exit 1
  ;;
esac

# Update Packages
apt update -y -q
apt install libguestfs-tools -y -q

# Download Cloud Image and Install qemu-guest-agent
wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
virt-customize -a "$CLOUD_IMAGE_FILE" --install qemu-guest-agent

# Setup user-data.yaml
rm -f "$USER_DATA"
cat <<EOF | tee "$USER_DATA"
#cloud init user data
users:
  - default
  - name: debian
    passwd: $6$rounds=4096$9L5WSrOX5xnefydm$0B5ID/erh6/g0W8omTfOPZX7aNWWDIDk8/p6PJBIF5P1/KPasCM2jR6NU97.DdOaa.SvTnbiXwA5KwlfQgnWa.
    lock-passwd: true
    ssh_pwauth: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, docker
    chpasswd:
      expire: false

apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable.
      keyid: 8D81803C0EBFCD88
      keyserver: 'https://download.docker.com/linux/debian/gpg'

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
  - docker-ce
  - docker-ce-cli
  - containerd.io

# create the docker group
groups:
  - docker

# Add default auto created user to docker group
system_info:
  default_user:
    groups: [docker]

EOF

# Build Template
qm create "$TEMPLATE_ID" --name "$TEMPLATE_NAME" --cores "$CORES" --memory "$MEMORY" --net0 virtio,bridge=vmbr0
qm importdisk "$TEMPLATE_ID" "$CLOUD_IMAGE_FILE" local-lvm
qm set "$TEMPLATE_ID" --scsi0 virtio-scsi-pci --scsi0 local-lvm:debian-12-template-disk-0
qm set "$TEMPLATE_ID" --ide2 local-lvm:cloudinit
qm set "$TEMPLATE_ID" --boot order=scsi0
qm set "$TEMPLATE_ID" --agent 1
qm set "$TEMPLATE_ID" --machine q35
qm set "$TEMPLATE_ID" --serial0 socket --vga serial0
qm set "$TEMPLATE_ID" --ipconfig0 ip=dhcp
qm set "$TEMPLATE_ID" --cicustom "user=local:snippets/user-data.yaml"
qm resize "$TEMPLATE_ID" scsi0 "$DISK_SIZE"
qm template "$TEMPLATE_ID"

# Clean up
rm $CLOUD_IMAGE_FILE
