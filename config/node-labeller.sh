#!/bin/bash
set -xeo pipefail
KVM_HYPERVISOR_DEVICE="kvm"
KVM_VIRTTYPE="kvm"
if [ -z "$HYPERVISOR_DEVICE" ] || [ -z "$PREFERRED_VIRTTYPE" ]; then
    HYPERVISOR_DEVICE="$KVM_HYPERVISOR_DEVICE"
    PREFERRED_VIRTTYPE="$KVM_VIRTTYPE"
fi
ARCH=$(uname -m)
MACHINE=q35
if [ "$ARCH" == "aarch64" ]; then
  MACHINE=virt
elif [ "$ARCH" == "s390x" ]; then
  MACHINE=s390-ccw-virtio
elif [ "$ARCH" == "ppc64le" ]; then
  MACHINE=pseries
elif [ "$ARCH" != "x86_64" ]; then
  exit 0
fi
set +o pipefail
HYPERVISOR_DEV_PATH="/dev/${HYPERVISOR_DEVICE}"
HYPERVISOR_DEV_MINOR=$(grep -w ${HYPERVISOR_DEVICE} /proc/misc | cut -f 1 -d' ')
set -o pipefail
VIRTTYPE=qemu
if [ ! -e "$HYPERVISOR_DEV_PATH" ] && [ -n "$HYPERVISOR_DEV_MINOR" ]; then
  mknod "$HYPERVISOR_DEV_PATH" c 10 "$HYPERVISOR_DEV_MINOR"
fi
if [ -e "$HYPERVISOR_DEV_PATH" ]; then
    chmod o+rw "$HYPERVISOR_DEV_PATH"
    VIRTTYPE=${PREFERRED_VIRTTYPE}
fi

mkdir -p /var/run/libvirt
libvirtd -d

for i in $(seq 1 30); do
  if [ -S /var/run/libvirt/libvirt-sock ]; then
    echo "Socket ready"
    break
  fi
  echo "Waiting for libvirtd socket... ($i)"
  sleep 1
done

virsh domcapabilities --machine $MACHINE --arch $ARCH --virttype $VIRTTYPE > /var/lib/kubevirt-node-labeller/virsh_domcapabilities.xml
virsh capabilities > /var/lib/kubevirt-node-labeller/capabilities.xml
