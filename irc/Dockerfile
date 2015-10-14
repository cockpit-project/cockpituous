FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y install bip openssl util-linux

VOLUME /home/user/data

ADD bip.conf bip-start /home/user/
RUN mkdir -p /home/user/data && chown -R user /home/user && chmod 755 /home/user/bip-start

EXPOSE 6667
CMD ["/home/user/bip-start"]

LABEL RUN /usr/bin/docker run --detach --restart=on-failure --publish=2003:6667 --name=irc IMAGE
