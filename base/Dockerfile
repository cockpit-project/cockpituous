FROM fedora:22
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y update
RUN dnf -y install git tar bzip2 python nc gnupg procps-ng util-linux rsync
RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user
RUN mkdir -p /home/user/.ssh && mkdir -p /usr/local/bin
