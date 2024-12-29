#!/usr/bin/bash

apt update -y -q
apt install libguestfs-tools -y -q

DISTRO="${DISTRO:-debian}"
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

CORES="${CORES:-1}"
MEMORY="${MEMORY:-2048}"
DISK_SIZE="${DISK_SIZE:-16G}"
TEMPLATE_ID="${TEMPLATE_ID:-9001}"
CLOUD_INIT_USER_FILE="https://raw.githubusercontent.com/proxmox-kubernetes/proxmox-template/refs/heads/main/user-data.yml"

echo Distro "$DISTRO"
echo Cloud Image URL "$CLOUD_IMAGE_URL"
echo Cloud Image File "$CLOUD_IMAGE_FILE"
echo Core "$CORES"
echo Memory "$MEMORY"
echo Disk Size "$DISK_SIZE"
echo Template ID "$TEMPLATE_ID"
echo Template Name "$TEMPLATE_NAME"

wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
virt-customize -a "$CLOUD_IMAGE_FILE" --install qemu-guest-agent

cat <<EOF | tee /var/lib/vz/snippets/user-data.yaml
#cloud-config

users:
  - default
  - name: debian
    passwd: "0ce00c6bde8a7e5d59cc6c3e170526c7f3d6c30986bb67bc9aab2834ceb3628a2d083f514c0364b5e43b87f4282e1b4cbd7a3f3728a0d2d9ba61666e7cf22ef5"
    lock-passwd: false
    chpasswd:
      expire: false

apt:
  sources:
    docker.list:
      source: deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian "$(/etc/os-release && echo $VERSION_CODENAME)" stable.
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
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

qm create "$TEMPLATE_ID" --name "$TEMPLATE_NAME" --cores "$CORES" --memory "$MEMORY" --net0 virtio,bridge=vmbr0
qm importdisk "$TEMPLATE_ID" "$CLOUD_IMAGE_FILE" local-lvm
qm set "$TEMPLATE_ID" --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-"$TEMPLATE_ID"-disk-0
qm set "$TEMPLATE_ID" --boot c --bootdisk scsi0
qm set "$TEMPLATE_ID" --ide2 local-lvm:cloudinit
qm set "$TEMPLATE_ID" --agent 1
qm set "$TEMPLATE_ID" --machine q35
qm set "$TEMPLATE_ID" --serial0 socket --vga serial0
qm set "$TEMPLATE_ID" --ipconfig0 ip=dhcp
qm set "$TEMPLATE_ID" --cicustom "user=local:snippets/user-data.yaml"
qm resize "$TEMPLATE_ID" scsi0 "$DISK_SIZE"
qm template "$TEMPLATE_ID"

rm $CLOUD_IMAGE_FILE
