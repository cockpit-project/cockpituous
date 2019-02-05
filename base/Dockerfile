FROM fedora:29
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update && \
    dnf -y install \
        bzip2 \
        findutils \
        git \
        gnupg \
        nc \
        procps-ng \
        python \
        rsync \
        tar \
        util-linux \
        && \
    dnf clean all
RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user && \
    mkdir -p /home/user/.ssh && mkdir -p /usr/local/bin

ENV LANG=C.UTF-8
