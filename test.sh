#!/usr/bin/env bash

TEMPLATES=(
  "debian https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  "ubuntu https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img"
)

for i in "${TEMPLATES[@]}"; do
  set -- $i
  ((VMID++))
  echo $1 $2
done

