#!/bin/bash
# Compila os binários Go e builda as imagens Docker para ppc64le
set -euo pipefail

KUBEVIRT_DIR="${KUBEVIRT_DIR:-$HOME/kubevirt}"
IMAGES_DIR="${IMAGES_DIR:-$HOME/kubevirt-images}"
REGISTRY="${REGISTRY:-192.168.49.1:5000}"
TAG="${TAG:-ppc64le-v1}"

echo "==> Compilando binários Go..."
cd "$KUBEVIRT_DIR"
go build -o virt-operator ./cmd/virt-operator/
go build -o virt-api ./cmd/virt-api/
go build -o virt-controller ./cmd/virt-controller/
go build -o virt-handler ./cmd/virt-handler/
go build -o virt-launcher ./cmd/virt-launcher/
go build -o virt-exportproxy ./cmd/virt-exportproxy/

echo "==> Compilando container-disk (C)..."
gcc -static -o container-disk cmd/container-disk-v2alpha/main.c -O2

echo "==> Copiando binários..."
mkdir -p "$IMAGES_DIR/bin"
cp virt-operator virt-api virt-controller virt-handler \
   virt-launcher virt-exportproxy container-disk \
   virt-chroot virt-probe virt-freezer virt-launcher-monitor virt-tail \
   "$IMAGES_DIR/bin/"

echo "==> Buildando e fazendo push das imagens..."
cd "$IMAGES_DIR"
for c in virt-launcher virt-handler virt-controller \
         virt-operator virt-api virt-exportproxy; do
    docker build -t "${REGISTRY}/kubevirt/${c}:${TAG}" -f "${c}/Dockerfile" .
    docker push "${REGISTRY}/kubevirt/${c}:${TAG}"
done

docker build -t "${REGISTRY}/kubevirt/cirros-disk:ppc64le" \
             -f fedora-containerdisk/Dockerfile .
docker push "${REGISTRY}/kubevirt/cirros-disk:ppc64le"

echo "==> Concluído. Tag: $TAG"
