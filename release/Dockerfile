FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y install git yum-utils npm tar bzip2 fedpkg copr-cli python python-irclib fpaste bind-utils nc gnupg freetype fontconfig krb5-workstation bodhi-client expect psmisc dpkg dpkg-dev pbuilder reprepro debian-keyring
RUN yum-builddep -y /tmp/cockpit.spec
RUN npm -g install phantomjs

RUN mkdir -p /usr/local/bin /home/user /build/rpmbuild
ADD * /usr/local/bin/

RUN chown -R user /build /home/user

ENV RELEASE_SINK fedorapeople.org
VOLUME /home/user
VOLUME /build
WORKDIR /build
USER user
ENTRYPOINT ["/usr/local/bin/cockpit-release"]
CMD ["dummy-arg"]
