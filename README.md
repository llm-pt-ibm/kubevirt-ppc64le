# KubeVirt on ppc64le (IBM POWER9)

Adaptation of [KubeVirt](https://kubevirt.io/) v1.8.2 for the IBM POWER9 architecture (ppc64le), enabling the creation and management of virtual machines via Kubernetes on an architecture not officially supported.

> **Related post:** [Running VMs with KubeVirt on IBM Power9](https://llm-pt-ibm.github.io/posts/kubevirt_ppc64le/) — an explanatory version with context and motivation.

## Overview

KubeVirt officially supports x86_64, arm64, and s390x. This repository contains all the patches, Dockerfiles, and instructions needed to build, install, and run KubeVirt on ppc64le.

```
kubevirt-ppc64le/
├── README.md
├── patches/
│   ├── build-tags/
│   │   └── setsched.go.patch
│   ├── node-labeller/
│   │   ├── kvm-caps-info-plugin_ppc64le.go
│   │   └── node-labeller.sh.patch
│   ├── virt-api/
│   │   ├── ppc64le.go
│   │   └── vmi-create-admitter.go.patch
│   ├── virt-config/
│   │   ├── virt-config.go.patch
│   │   └── configuration.go.patch
│   ├── arch-defaulter/
│   │   ├── ppc64le.go
│   │   └── archdefaults.go.patch
│   ├── converter/
│   │   ├── ppc64le.go
│   │   ├── converter.go.patch
│   │   └── graphics.go.patch
│   └── runtime/
│       ├── virt-launcher-monitor.go.patch
│       └── libvirt_helper.go.patch
├── dockerfiles/
│   ├── virt-operator/Dockerfile
│   ├── virt-api/Dockerfile
│   ├── virt-controller/Dockerfile
│   ├── virt-handler/Dockerfile
│   ├── virt-launcher/Dockerfile
│   ├── virt-exportproxy/Dockerfile
│   └── cirros-disk/Dockerfile
├── manifests/
│   └── test-vmi.yaml
└── scripts/
    ├── build.sh
    └── deploy.sh
```

## Environment

| Component   | Version                         |
|-------------|---------------------------------|
| Hardware    | IBM POWER9 (ppc64le)            |
| OS          | AlmaLinux 8.10                  |
| Docker      | Docker CE 26.1.3                |
| minikube    | v1.38.0 (docker + containerd)   |
| Kubernetes  | v1.35.0                         |
| KubeVirt    | v1.8.2                          |
| Go          | 1.24.9                          |
| GCC         | 8.5.0                           |
| GPU         | 4x Tesla V100-SXM2-16GB         |

## Prerequisites

### 1. Kubernetes Cluster

minikube is used as the local cluster. The default CNI (kindnet) has no ppc64le image, so Calico must be used:

```bash
sudo usermod -aG docker $USER
newgrp docker
minikube start --driver=docker --container-runtime=containerd --cni=calico
```

### 2. Local Registry

A local registry serves images to minikube:

```bash
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

### 3. Build Dependencies

**libnbd 1.20** (AlmaLinux 8 only ships 1.6):

```bash
curl -O https://download.libguestfs.org/libnbd/1.20-stable/libnbd-1.20.3.tar.gz
tar xzf libnbd-1.20.3.tar.gz && cd libnbd-1.20.3
./configure --prefix=/usr --libdir=/usr/lib64
make -j$(nproc) && sudo make install
```

**glibc-static** (for the container-disk):

```bash
sudo yum install -y glibc-static libvirt-devel
```

## Build

### Clone KubeVirt

```bash
git clone https://github.com/kubevirt/kubevirt.git -b v1.8.2
cd kubevirt
```

### Apply the Patches

```bash
# New files — copy to the correct directories
cp patches/node-labeller/kvm-caps-info-plugin_ppc64le.go \
   pkg/virt-handler/node-labeller/

cp patches/virt-api/ppc64le.go \
   pkg/virt-api/webhooks/

cp patches/arch-defaulter/ppc64le.go \
   pkg/virt-launcher/virtwrap/api/arch-defaulter/

cp patches/converter/ppc64le.go \
   pkg/virt-launcher/virtwrap/converter/arch/

# Patches to existing files
git apply patches/build-tags/setsched.go.patch
git apply patches/node-labeller/node-labeller.sh.patch
git apply patches/virt-api/vmi-create-admitter.go.patch
git apply patches/virt-config/virt-config.go.patch
git apply patches/virt-config/configuration.go.patch
git apply patches/arch-defaulter/archdefaults.go.patch
git apply patches/converter/converter.go.patch
git apply patches/converter/graphics.go.patch
git apply patches/runtime/virt-launcher-monitor.go.patch
git apply patches/runtime/libvirt_helper.go.patch
```

### Build the Binaries

```bash
go build -o virt-operator ./cmd/virt-operator/
go build -o virt-api ./cmd/virt-api/
go build -o virt-controller ./cmd/virt-controller/
go build -o virt-handler ./cmd/virt-handler/
go build -o virt-launcher ./cmd/virt-launcher/
go build -o virt-exportproxy ./cmd/virt-exportproxy/
```

### Build the container-disk (C)

```bash
gcc -static -o container-disk cmd/container-disk-v2alpha/main.c -O2
```

## Building the Images

Copy the binaries and build the images:

```bash
mkdir -p ~/kubevirt-images/bin
cp virt-operator virt-api virt-controller virt-handler \
   virt-launcher virt-exportproxy container-disk ~/kubevirt-images/bin/

# Copy the Dockerfiles from this repository
cp -r dockerfiles/* ~/kubevirt-images/

cd ~/kubevirt-images
TAG="ppc64le-v4"
for c in virt-launcher virt-handler virt-controller \
         virt-operator virt-api virt-exportproxy; do
    docker build -t 192.168.49.1:5000/kubevirt/${c}:${TAG} \
                 -f ${c}/Dockerfile .
    docker push 192.168.49.1:5000/kubevirt/${c}:${TAG}
done
```

### containerDisk Image (CirrOS ppc64le)

```bash
docker build -t 192.168.49.1:5000/kubevirt/cirros-disk:ppc64le \
             -f cirros-disk/Dockerfile .
docker push 192.168.49.1:5000/kubevirt/cirros-disk:ppc64le
```

## Deploy

### Install KubeVirt

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.8.2/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.8.2/kubevirt-cr.yaml
```

### Configure Local Images

```bash
kubectl patch kubevirt kubevirt -n kubevirt --type merge \
  -p '{"spec":{"imageTag":"ppc64le-v4"}}'
kubectl delete pods -n kubevirt --all
```

### Node Labels

```bash
kubectl label node minikube cpu-model.node.kubevirt.io/POWER9=true --overwrite
```

### Verify Components

```bash
kubectl get pods -n kubevirt
```

All pods should be `Running`.

```bash
kubectl get kubevirt -n kubevirt
```

Expected: `PHASE: Deployed`.

## Running a VM

```bash
kubectl apply -f manifests/test-vmi.yaml
```

The `manifests/test-vmi.yaml` file contains:

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
metadata:
  name: test-vmi
spec:
  architecture: ppc64le
  domain:
    cpu:
      model: POWER9
      cores: 1
    devices:
      autoattachGraphicsDevice: false
      disks:
      - disk:
          bus: virtio
        name: containerdisk
    machine:
      type: pseries
    resources:
      requests:
        memory: 512Mi
  volumes:
  - containerDisk:
      image: 192.168.49.1:5000/kubevirt/cirros-disk:ppc64le
    name: containerdisk
```

### Key Parameters

| Parameter                       | Value      | Reason                                                                 |
|---------------------------------|------------|------------------------------------------------------------------------|
| `architecture`                  | `ppc64le`  | Sets the VM architecture                                               |
| `cpu.model`                     | `POWER9`   | `host-model` does not work under nested virtualization                 |
| `autoattachGraphicsDevice`      | `false`    | Workaround for USB/VNC conflict on pseries                             |
| `machine.type`                  | `pseries`  | Virtual machine type for POWER                                         |
| `disk.bus`                      | `virtio`   | Paravirtualized disk bus                                               |

### Verify

```bash
kubectl get vmi test-vmi -o wide
```

Expected output:

```
NAME       AGE     PHASE     IP               NODENAME   READY
test-vmi   2m43s   Running   10.244.120.124   minikube   True
```

### Access the VM

```bash
virtctl console test-vmi
```

Or via kubectl:

```bash
kubectl exec -it $(kubectl get pods | grep test-vmi | awk '{print $1}') \
  -c compute -- virsh -c qemu:///session list --all
```

## Results

Data collected from inside the VM:

```
$ uname -a
Linux cirros 5.15.0-71-generic #78-Ubuntu SMP ppc64le GNU/Linux

$ lscpu
Architecture:          ppc64le
CPU(s):                1
Model name:            POWER9 (architected), altivec supported
Hypervisor vendor:     KVM
Virtualization type:   para

$ cat /proc/cpuinfo
processor  : 0
cpu        : POWER9 (architected), altivec supported
platform   : pSeries
model      : IBM pSeries (emulated by qemu)
machine    : CHRP IBM pSeries (emulated by qemu)
MMU        : Radix
```

## Modified Files

### New Files

| File                                                               | Purpose                                            |
|--------------------------------------------------------------------|----------------------------------------------------|
| `pkg/virt-handler/node-labeller/kvm-caps-info-plugin_ppc64le.go`  | KVM capabilities for ppc64le (stub)                |
| `pkg/virt-api/webhooks/ppc64le.go`                                 | VMI validation for ppc64le                         |
| `pkg/virt-launcher/virtwrap/api/arch-defaulter/ppc64le.go`         | OS type defaults (arch=ppc64le, machine=pseries)   |
| `pkg/virt-launcher/virtwrap/converter/arch/ppc64le.go`             | Converter interface for ppc64le                    |

### Modified Files

| File                                                               | Change                                             |
|--------------------------------------------------------------------|----------------------------------------------------|
| `pkg/hypervisor/common/setsched.go`                                | Build tag: add `(linux && ppc64le)`                |
| `pkg/virt-config/virt-config.go`                                   | Defaults: `pseries`, `pseries*`                    |
| `pkg/virt-config/configuration.go`                                 | `Ppc64le` block in config, cases in getters        |
| `pkg/virt-api/.../vmi-create-admitter.go`                          | `ppc64le` cases in validation switches             |
| `cmd/virt-launcher-monitor/virt-launcher-monitor.go`               | Remove AmbientCaps                                 |
| `pkg/virt-launcher/virtwrap/util/libvirt_helper.go`                | Remove AmbientCaps                                 |
| `pkg/virt-launcher/virtwrap/api/arch-defaulter/archdefaults.go`    | `ppc64le` case in NewArchDefaulter                 |
| `pkg/virt-launcher/virtwrap/converter/arch/converter.go`           | Constant and `ppc64le` case in NewConverter        |
| `pkg/virt-launcher/virtwrap/converter/compute/graphics.go`         | `virtio` video device for ppc64le                  |
| `node-labeller.sh`                                                 | ppc64le support, `libvirtd` instead of `virtqemud` |

### Dependencies Built from Source

| Dependency | Version | Reason                                                   |
|------------|---------|----------------------------------------------------------|
| libnbd     | 1.20.3  | AlmaLinux 8 only ships 1.6; virt-launcher requires 1.18+ |

## Known Limitations

- **VNC disabled**: `autoattachGraphicsDevice: false` is required as a workaround for a USB conflict on pseries.
- **Manual CPU model**: `cpu.model: POWER9` must be set explicitly in the VMI because `host-model` does not work under nested virtualization.
- **Live migration unavailable**: bridge networking does not allow migration; masquerade is required.

## Next Steps

- Resolve the USB/Graphics conflict to enable VNC;
- Set the default CPU model for ppc64le in code;
- Explore GPU passthrough (V100) via KubeVirt;
- Test other distros as containerDisk images (Fedora, Ubuntu, AlmaLinux);
- Upstream the patches to KubeVirt;
- Validate on Single Node OpenShift (OCP 4.21).

## References

- [KubeVirt Documentation](https://kubevirt.io/user-guide/)
- [KubeVirt GitHub](https://github.com/kubevirt/kubevirt)
- [KubeVirt Architecture](https://kubevirt.io/user-guide/architecture/)
- [Blog post: Running VMs with KubeVirt on IBM Power9](https://llm-pt-ibm.github.io/posts/kubevirt_ppc64le/)
