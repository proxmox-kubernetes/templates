#!/usr/bin/env bash

declare -A TEMPLATES=(
  [debian]=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
  [ubuntu]=https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img
)

for NAME in "${!TEMPLATES[@]}"; do
  echo $NAME ${TEMPLATES[$NAME]}
done

