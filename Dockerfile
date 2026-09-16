ARG FEDORA_VERSION

FROM registry.fedoraproject.org/fedora:$FEDORA_VERSION

RUN dnf install -y lorax \
                   pykickstart \
      && dnf clean all

COPY . /home/fedora
RUN chmod +x /home/fedora/entrypoint.sh

WORKDIR /home/fedora
ENTRYPOINT ["/home/fedora/entrypoint.sh"]
