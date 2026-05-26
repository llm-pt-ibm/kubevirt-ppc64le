FROM almalinux:8

RUN dnf install -y \
    qemu-kvm \
    libvirt-client \
    libvirt-daemon \
    libvirt-daemon-kvm \
    libvirt-daemon-driver-qemu \
    && dnf clean all \
    && mkdir -p /var/lib/kubevirt-node-labeller

COPY bin/ /usr/bin/
COPY libnbd.so.0* /usr/lib64/
COPY node-labeller.sh /usr/bin/node-labeller.sh
COPY qemu.conf /etc/libvirt/qemu.conf
COPY virtqemud.conf /etc/libvirt/virtqemud.conf
COPY nsswitch.conf /etc/nsswitch.conf

RUN chmod +x /usr/bin/node-labeller.sh && \
    ldconfig && \
    chmod o+r /etc/libvirt/qemu.conf /etc/libvirt/virtqemud.conf && \
    chmod o+rx /etc/libvirt/

ENTRYPOINT ["/usr/bin/virt-launcher"]
