FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y install openssh-server rsync
RUN mkdir -p /var/run/sshd && mkdir /guide && mkdir -p /home/user/.ssh
ADD authorized_keys /home/user/.ssh/
RUN chown 1111 -R /guide /home/user/.ssh

VOLUME /guide
EXPOSE 22
LABEL RUN /usr/bin/docker run --daemon --volume /srv/guide:/guide --restart=on-failure --publish 2001:22 IMAGE

CMD ["/usr/sbin/sshd", "-D"]
