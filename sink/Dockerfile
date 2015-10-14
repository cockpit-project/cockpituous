FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y install openssh-server
RUN mkdir -p /var/run/sshd && mkdir /logs && mkdir -p /home/user/.ssh && mkdir -p /usr/local/bin
ADD * /usr/local/bin/
RUN mv /usr/local/bin/authorized_keys /home/user/.ssh/
RUN chown user -R /logs /home/user/.ssh && chmod -R go-rwx /home/user/.ssh

ENV LOGS /logs
VOLUME /logs
EXPOSE 22
CMD ["/usr/local/bin/sshd", "-D"]

LABEL RUN /usr/bin/docker run --name=sink --detach --restart=on-failure --volume=/srv/logs:/logs:rw --publish=2002:22 IMAGE
