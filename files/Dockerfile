FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y install openssh-server rsync
RUN mkdir -p /var/run/sshd && mkdir /files && mkdir -p /home/user/.ssh && mkdir -p /usr/local/bin
ADD * /usr/local/bin/
RUN mv /usr/local/bin/authorized_keys /home/user/.ssh/
RUN chown user -R /files /home/user/.ssh && chmod -R go-rwx /home/user/.ssh

VOLUME /files
EXPOSE 22
CMD ["/usr/local/bin/sshd", "-D"]

LABEL RUN /usr/bin/docker run --detach --volume /srv:/files:rw --restart=on-failure --publish 2001:22 --name=files IMAGE
