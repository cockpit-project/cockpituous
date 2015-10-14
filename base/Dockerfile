FROM fedora:22
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y update
RUN dnf -y install git tar bzip2 python nc gnupg procps-ng util-linux rsync
RUN groupadd -r user && useradd -r -g user -u 1111 user

