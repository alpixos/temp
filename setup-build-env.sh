#!/bin/bash

# Variables
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.0-x86_64.iso"
ISO_PATH="./alpine-virt-3.20.0-x86_64.iso"
DISK_IMAGE="./alpine_disk.img"
RAM_SIZE=2048 # MB
DISK_SIZE=15G
VNC_PORT=3088

# Check if ISO exists, download if not
if [! -f "$ISO_PATH" ]; then
    echo "Downloading Alpine Linux ISO..."
    wget $ISO_URL -O $ISO_PATH
fi

# Create disk image if it doesn't exist
if [! -f "$DISK_IMAGE" ]; then
    echo "Creating disk image..."
    qemu-img create -f qcow2 $DISK_IMAGE $DISK_SIZE
fi

# Start QEMU VM
echo "Starting QEMU VM..."
qemu-system-x86_64 \
    -m $RAM_SIZE \
    -hda $DISK_IMAGE \
    -cdrom $ISO_PATH \
    -boot d \
    -vga std \
    -display none \
    -vnc :$VNC_PORT \
    -netdev user,id=usernet,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=usernet \
    -enable-kvm
