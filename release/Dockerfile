FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y install git yum-utils npm tar bzip2 fedpkg copr-cli python python-irclib fpaste bind-utils nc gnupg freetype fontconfig krb5-workstation bodhi-client expect psmisc
RUN yum-builddep -y /tmp/cockpit.spec
RUN npm -g install phantomjs

RUN mkdir -p /usr/local/bin /home/user /build/rpmbuild
ADD * /usr/local/bin/

RUN chown -R user /build /home/user
RUN runuser -u user -- /bin/sh -c "git -C /build clone https://github.com/cockpit-project/cockpit && cd /build/cockpit/tools && npm install"

RUN printf "\nHost sink.cockpit-project.org\n\tUser user\n\tPort 2002\n\tHostName files.cockpit-project.org\n" >> /etc/ssh/ssh_config
RUN printf "\nHost files.cockpit-project.org\n\tUser user\n\tPort 2001\n" >> /etc/ssh/ssh_config


ENV RELEASE_BASE /build/cockpit
ENV RELEASE_SINK fedorapeople.org
VOLUME /home/user
USER user
CMD ["/usr/local/bin/release-runner", "/usr/local/bin/cockpit-script"]

LABEL RUN /usr/bin/docker run -ti --volume=/home/cockpit:/home/user:rw IMAGE /bin/bash
