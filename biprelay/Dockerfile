FROM fedora:22
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y update
RUN dnf -y install bip openssl util-linux

VOLUME /home/bip/data
EXPOSE 6667

ADD bip.conf bip-start /home/bip/
RUN mkdir -p /home/bip/data && chmod 755 /home/bip/bip-start

CMD ["/home/bip/bip-start"]
