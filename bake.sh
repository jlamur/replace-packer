#!/usr/bin/env bash

set -euo pipefail

ubuntu_image=ubuntu-22.04-minimal-cloudimg-amd64.img
overlay_image=img.qcow2

if [ ! -f "$ubuntu_image" ]; then
	echo "missing $ubuntu_image; download it with eg.:" >&2
	echo "  $ curl https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img -o $ubuntu_image" >&2
	exit 0
fi

tmp=$(mktemp -d --suffix replace-packer)
trap 'rm -rf $tmp' EXIT

cat > "$tmp/metadata.yaml" <<EOF
instance-id: id
local-hostname: replace-packer
EOF
cat > "$tmp/user-data.yaml" <<EOF
#cloud-config
ssh_pwauth: true
chpasswd:
    expire: false
    users:
      - name: ubuntu
        password: ubuntu
        type: text

# Custom commands here
runcmd:
    - touch /coucou

# Power off as soon as cloudinit finished.
# This will not catch cases where cloudinit failed, we must read
# /run/cloud-init/result.json in that case or just timeout the qemu command
# below.
power_state:
    delay: now
    mode: poweroff
EOF

cloud-localds "$tmp/seed.img" "$tmp/user-data.yaml" "$tmp/metadata.yaml"

qemu-img create -o "backing_file=$ubuntu_image,backing_fmt=qcow2" -f qcow2 "$overlay_image"

qemu-system-x86_64 \
	-machine accel=kvm,type=q35 \
	-cpu host \
	-m 2G \
	-nographic \
	-device virtio-net-pci,netdev=net0 \
	-netdev user,id=net0 \
	-drive "if=virtio,format=qcow2,file=$overlay_image" \
	-drive "if=virtio,format=raw,file=$tmp/seed.img"
