#!/bin/sh

# Define global variables
ISO_NAME="alpix"
ISO_OUTPUT="/output/alpix.iso" # Adjust the output path to a mounted volume
WORKDIR=$(mktemp -d)
APKS="firefox git htop wget curl"
DESKTOP_ENV="plasma-desktop"
KERNEL_PKG="linux-lts"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.0-x86_64.tar.gz"
RETRY_COUNT=5

# Step 1: Prepare the environment
prepare_environment() {
    echo "Preparing environment..."
    apk update
    apk add --no-cache alpine-sdk xorriso squashfs-tools grub
}

# Step 2: Download and extract Alpine Linux mini root filesystem
download_and_extract() {
    echo "Downloading and extracting Alpine Linux mini root filesystem..."
    wget -O $WORKDIR/alpine-minirootfs.tar.gz $MINIROOTFS_URL
    mkdir -p $WORKDIR/rootfs
    tar -xzf $WORKDIR/alpine-minirootfs.tar.gz -C $WORKDIR/rootfs
}

# Step 3: Configure the root filesystem with retries
configure_rootfs() {
    echo "Configuring root filesystem..."
    
    for i in $(seq 1 $RETRY_COUNT); do
        chroot $WORKDIR/rootfs /bin/sh <<EOF
        apk update && apk add --no-cache $APKS $DESKTOP_ENV $KERNEL_PKG
        if [ \$? -eq 0 ]; then
            echo "Packages installed successfully"
            break
        else
            echo "Retrying package installation... Attempt \$i"
            sleep 5
        fi
EOF
        if [ $? -eq 0 ]; then
            break
        fi
    done

    echo "root:root" | chpasswd
}

# Step 4: Create bootable ISO
create_iso() {
    echo "Creating bootable ISO..."
    mkdir -p $WORKDIR/iso/boot
    mkdir -p $WORKDIR/iso/boot/grub

    KERNEL_FILE=$(ls $WORKDIR/rootfs/boot/vmlinuz-* | head -n 1)
    INITRAMFS_FILE=$(ls $WORKDIR/rootfs/boot/initramfs-* | head -n 1)

    if [ -z "$KERNEL_FILE" ] || [ -z "$INITRAMFS_FILE" ]; then
        echo "Error: Kernel or initramfs files not found!"
        exit 1
    fi

    cp $KERNEL_FILE $WORKDIR/iso/boot/vmlinuz
    cp $INITRAMFS_FILE $WORKDIR/iso/boot/initramfs

    cat <<EOF > $WORKDIR/iso/boot/grub/grub.cfg
menuentry "Alpix" {
    linux /boot/vmlinuz root=/dev/sr0
    initrd /boot/initramfs
}
EOF

    xorriso -as mkisofs -o $ISO_OUTPUT -isohybrid-mbr /usr/lib/syslinux/mbr/isohdpfx.bin \
        -c isolinux/boot.cat -b boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        $WORKDIR/iso
}

# Step 5: Clean up
cleanup() {
    echo "Cleaning up..."
    rm -rf $WORKDIR
}

# Main function to orchestrate the build
main() {
    prepare_environment
    download_and_extract
    configure_rootfs
    create_iso
    cleanup
    echo "Custom ISO $ISO_NAME created successfully as $ISO_OUTPUT"
}

# Execute main function
main
