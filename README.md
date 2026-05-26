# KubeVirt em ppc64le (IBM POWER9)

Adaptação do [KubeVirt](https://kubevirt.io/) v1.8.2 para a arquitetura IBM POWER9 (ppc64le), permitindo criar e gerenciar máquinas virtuais via Kubernetes em uma arquitetura não suportada oficialmente.

> **Post relacionado:** [Executando VMs com KubeVirt na IBM Power9](https://llm-pt-ibm.github.io/posts/kubevirt_ppc64le/) — versão explicativa com contexto e motivação.

## Visão Geral

O KubeVirt oficialmente suporta x86_64, arm64 e s390x. Este repositório contém todos os patches, Dockerfiles e instruções necessários para compilar, instalar e executar o KubeVirt em ppc64le.

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

## Ambiente

| Componente  | Versão                          |
|-------------|---------------------------------|
| Hardware    | IBM POWER9 (ppc64le)            |
| SO          | AlmaLinux 8.10                  |
| Docker      | Docker CE 26.1.3                |
| minikube    | v1.38.0 (docker + containerd)   |
| Kubernetes  | v1.35.0                         |
| KubeVirt    | v1.8.2                          |
| Go          | 1.24.9                          |
| GCC         | 8.5.0                           |
| GPU         | 2x Tesla V100-SXM2-16GB        |

## Pré-requisitos

### 1. Cluster Kubernetes

O minikube é utilizado como cluster local. O CNI padrão (kindnet) não possui imagem ppc64le, então é necessário usar o Calico:

```bash
sudo usermod -aG docker $USER
newgrp docker
minikube start --driver=docker --container-runtime=containerd --cni=calico
```

### 2. Registry local

Um registry local serve as imagens para o minikube:

```bash
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

### 3. Dependências de compilação

**libnbd 1.20** (o AlmaLinux 8 só tem 1.6):

```bash
curl -O https://download.libguestfs.org/libnbd/1.20-stable/libnbd-1.20.3.tar.gz
tar xzf libnbd-1.20.3.tar.gz && cd libnbd-1.20.3
./configure --prefix=/usr --libdir=/usr/lib64
make -j$(nproc) && sudo make install
```

**glibc-static** (para o container-disk):

```bash
sudo yum install -y glibc-static libvirt-devel
```

## Compilação

### Clonar o KubeVirt

```bash
git clone https://github.com/kubevirt/kubevirt.git -b v1.8.2
cd kubevirt
```

### Aplicar os patches

```bash
# Arquivos novos — copiar para os diretórios corretos
cp patches/node-labeller/kvm-caps-info-plugin_ppc64le.go \
   pkg/virt-handler/node-labeller/

cp patches/virt-api/ppc64le.go \
   pkg/virt-api/webhooks/

cp patches/arch-defaulter/ppc64le.go \
   pkg/virt-launcher/virtwrap/api/arch-defaulter/

cp patches/converter/ppc64le.go \
   pkg/virt-launcher/virtwrap/converter/arch/

# Patches em arquivos existentes
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

### Compilar os binários

```bash
go build -o virt-operator ./cmd/virt-operator/
go build -o virt-api ./cmd/virt-api/
go build -o virt-controller ./cmd/virt-controller/
go build -o virt-handler ./cmd/virt-handler/
go build -o virt-launcher ./cmd/virt-launcher/
go build -o virt-exportproxy ./cmd/virt-exportproxy/
```

### Compilar o container-disk (C)

```bash
gcc -static -o container-disk cmd/container-disk-v2alpha/main.c -O2
```

## Criação das imagens

Copiar os binários e buildar as imagens:

```bash
mkdir -p ~/kubevirt-images/bin
cp virt-operator virt-api virt-controller virt-handler \
   virt-launcher virt-exportproxy container-disk ~/kubevirt-images/bin/

# Copiar os Dockerfiles deste repositório
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

### Imagem containerDisk (CirrOS ppc64le)

```bash
docker build -t 192.168.49.1:5000/kubevirt/cirros-disk:ppc64le \
             -f cirros-disk/Dockerfile .
docker push 192.168.49.1:5000/kubevirt/cirros-disk:ppc64le
```

## Deploy

### Instalar o KubeVirt

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.8.2/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.8.2/kubevirt-cr.yaml
```

### Configurar as imagens locais

```bash
kubectl patch kubevirt kubevirt -n kubevirt --type merge \
  -p '{"spec":{"imageTag":"ppc64le-v4"}}'
kubectl delete pods -n kubevirt --all
```

### Labels do node

```bash
kubectl label node minikube cpu-model.node.kubevirt.io/POWER9=true --overwrite
```

### Verificar os componentes

```bash
kubectl get pods -n kubevirt
```

Todos os pods devem estar `Running`.

```bash
kubectl get kubevirt -n kubevirt
```

Esperado: `PHASE: Deployed`.

## Executando uma VM

```bash
kubectl apply -f manifests/test-vmi.yaml
```

O arquivo `manifests/test-vmi.yaml` contém:

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

### Parâmetros importantes

| Parâmetro                       | Valor      | Motivo                                                                 |
|---------------------------------|------------|------------------------------------------------------------------------|
| `architecture`                  | `ppc64le`  | Define a arquitetura da VM                                             |
| `cpu.model`                     | `POWER9`   | `host-model` não funciona em virtualização aninhada                    |
| `autoattachGraphicsDevice`      | `false`    | Workaround para conflito USB/VNC em pseries                            |
| `machine.type`                  | `pseries`  | Tipo de máquina virtual para POWER                                     |
| `disk.bus`                      | `virtio`   | Barramento de disco paravirtualizado                                   |

### Verificar

```bash
kubectl get vmi test-vmi -o wide
```

Resultado esperado:

```
NAME       AGE     PHASE     IP               NODENAME   READY
test-vmi   2m43s   Running   10.244.120.124   minikube   True
```

### Acessar a VM

```bash
virtctl console test-vmi
```

Ou via kubectl:

```bash
kubectl exec -it $(kubectl get pods | grep test-vmi | awk '{print $1}') \
  -c compute -- virsh -c qemu:///session list --all
```

## Resultados

Dados coletados de dentro da VM:

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

## Arquivos modificados

### Arquivos novos

| Arquivo                                                    | Função                                        |
|------------------------------------------------------------|-----------------------------------------------|
| `pkg/virt-handler/node-labeller/kvm-caps-info-plugin_ppc64le.go` | KVM capabilities para ppc64le (vazio)   |
| `pkg/virt-api/webhooks/ppc64le.go`                         | Validação de VMI ppc64le                      |
| `pkg/virt-launcher/virtwrap/api/arch-defaulter/ppc64le.go` | OS type defaults (arch=ppc64le, machine=pseries) |
| `pkg/virt-launcher/virtwrap/converter/arch/ppc64le.go`     | Interface Converter para ppc64le              |

### Arquivos modificados

| Arquivo                                                    | Mudança                                       |
|------------------------------------------------------------|-----------------------------------------------|
| `pkg/hypervisor/common/setsched.go`                        | Build tag: adicionar `(linux && ppc64le)`      |
| `pkg/virt-config/virt-config.go`                           | Defaults: `pseries`, `pseries*`               |
| `pkg/virt-config/configuration.go`                         | Bloco `Ppc64le` no config, cases nos getters  |
| `pkg/virt-api/.../vmi-create-admitter.go`                  | Cases `ppc64le` nos switches de validação     |
| `cmd/virt-launcher-monitor/virt-launcher-monitor.go`       | Remover AmbientCaps                           |
| `pkg/virt-launcher/virtwrap/util/libvirt_helper.go`        | Remover AmbientCaps                           |
| `pkg/virt-launcher/virtwrap/api/arch-defaulter/archdefaults.go` | Case `ppc64le` no NewArchDefaulter       |
| `pkg/virt-launcher/virtwrap/converter/arch/converter.go`   | Constante e case `ppc64le` no NewConverter    |
| `pkg/virt-launcher/virtwrap/converter/compute/graphics.go` | Video device `virtio` para ppc64le            |
| `node-labeller.sh`                                         | Suporte ppc64le, `libvirtd` em vez de `virtqemud` |

### Dependências compiladas do fonte

| Dependência    | Versão | Motivo                                     |
|----------------|--------|--------------------------------------------|
| libnbd         | 1.20.3 | AlmaLinux 8 só tem 1.6, virt-launcher requer 1.18+ |

## Limitações conhecidas

- **VNC desabilitado**: `autoattachGraphicsDevice: false` é necessário como workaround para conflito USB em pseries.
- **CPU model manual**: é necessário especificar `cpu.model: POWER9` na VMI porque `host-model` não funciona em virtualização aninhada.
- **Live migration indisponível**: bridge networking não permite migração; necessário masquerade.

## Próximos passos

- Resolver o conflito USB/Graphics para habilitar VNC;
- Ajustar o CPU model default para ppc64le no código;
- Explorar GPU passthrough (V100) via KubeVirt;
- Testar outras distros como containerDisk (Fedora, Ubuntu, AlmaLinux);
- Contribuir os patches ao KubeVirt upstream;
- Validar no Single Node OpenShift (OCP 4.21).

## Referências

- [KubeVirt Documentation](https://kubevirt.io/user-guide/)
- [KubeVirt GitHub](https://github.com/kubevirt/kubevirt)
- [KubeVirt Architecture](https://kubevirt.io/user-guide/architecture/)
- [Post do blog: Executando VMs com KubeVirt na IBM Power9](https://llm-pt-ibm.github.io/posts/kubevirt_ppc64le/)
