#!/usr/bin/env bash

set -euo pipefail

overlay_image=img.qcow2

qemu-system-x86_64 \
	-machine accel=kvm,type=q35 \
	-cpu host \
	-m 2G \
	-nographic \
	-device virtio-net-pci,netdev=net0 \
	-netdev user,id=net0 \
	-drive "if=virtio,format=qcow2,file=$overlay_image"
