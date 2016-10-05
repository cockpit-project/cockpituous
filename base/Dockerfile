FROM fedora:24
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y update && \
    dnf -y install \
        bzip2 \
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
RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user
RUN mkdir -p /home/user/.ssh && mkdir -p /usr/local/bin
