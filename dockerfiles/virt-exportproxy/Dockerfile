FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
COPY bin/virt-exportproxy /usr/bin/virt-exportproxy
USER 1001
ENTRYPOINT ["/usr/bin/virt-exportproxy"]
