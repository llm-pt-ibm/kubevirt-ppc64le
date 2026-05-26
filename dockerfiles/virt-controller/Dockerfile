FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
COPY bin/virt-controller /usr/bin/virt-controller
USER 1001
ENTRYPOINT ["/usr/bin/virt-controller"]
