FROM fedora:22
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN groupadd -r build && useradd -r -g build -u 1000 build
RUN dnf -y update

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y install git yum-utils npm tar bzip2 fedpkg copr-cli python python-irclib fpaste bind-utils nc gnupg freetype fontconfig krb5-workstation bodhi-client expect
RUN yum-builddep -y /tmp/cockpit.spec
RUN npm -g install phantomjs

RUN mkdir -p /opt/scripts /usr/local/bin /home/build /opt/build/rpmbuild
COPY * /opt/scripts/
RUN ln -sf /opt/scripts/release-* /usr/local/bin && ln -sf /opt/scripts/check-git-rw /usr/local/bin

RUN chown -R build /opt /home/build
RUN runuser -u build -- /bin/sh -c "git -C /opt/build clone https://github.com/cockpit-project/cockpit && cd /opt/build/cockpit/tools && npm install"

VOLUME /home/build
USER build

CMD ["/bin/bash"]
