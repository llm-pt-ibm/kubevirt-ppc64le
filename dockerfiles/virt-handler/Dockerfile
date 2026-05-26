FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

RUN microdnf install -y procps-ng shadow-utils && \
    microdnf clean all && \
    useradd -u 107 -r -s /sbin/nologin qemu

COPY bin/virt-handler /usr/bin/virt-handler
COPY bin/virt-chroot /usr/bin/virt-chroot
COPY bin/virt-probe /usr/bin/virt-probe
COPY bin/virt-freezer /usr/bin/virt-freezer
COPY bin/virt-launcher /usr/bin/virt-launcher
COPY bin/virt-launcher-monitor /usr/bin/virt-launcher-monitor

ENTRYPOINT ["/usr/bin/virt-handler"]
