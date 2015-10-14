FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y install git yum-utils npm tar bzip2 fedpkg copr-cli python python-irclib fpaste bind-utils nc gnupg freetype fontconfig krb5-workstation bodhi-client expect
RUN yum-builddep -y /tmp/cockpit.spec
RUN npm -g install phantomjs

RUN mkdir -p /scripts /usr/local/bin /home/user /build/rpmbuild
COPY * /scripts/
RUN ln -sf /scripts/release-* /usr/local/bin && ln -sf /scripts/check-git-rw /usr/local/bin

RUN chown -R user /build /home/user
RUN runuser -u user -- /bin/sh -c "git -C /build clone https://github.com/cockpit-project/cockpit && cd /build/cockpit/tools && npm install"

VOLUME /home/user
USER user

LABEL RUN /usr/bin/docker run --daemon --restart=on-failure --volume /home/cockpit:/home/user IMAGE /scripts/release-daemon

CMD ["/bin/bash"]
