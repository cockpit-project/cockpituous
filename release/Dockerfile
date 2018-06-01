FROM cockpit/infra-base
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y update && \
    dnf -y install \
bind-utils \
bodhi-client \
bzip2 \
debian-keyring \
devscripts \
dpkg \
dpkg-dev \
expect \
fontconfig \
fpaste \
freetype \
git \
gnupg \
hardlink \
krb5-workstation \
nc \
npm \
origin-clients \
psmisc \
python \
python-irclib \
reprepro \
rpm-build \
tar \
which \
yum-utils \
    && \
    dnf -y install --enablerepo=updates-testing fedpkg koji copr-cli && \
    dnf -y install 'dnf-command(builddep)' && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all && \
    mkdir -p /usr/local/bin /home/user /build/rpmbuild && \
    chmod g=u /etc/passwd && \
    chown -R user /build /home/user

ADD * /usr/local/bin/

VOLUME /home/user /build
WORKDIR /build
USER user
ENTRYPOINT ["/usr/local/bin/release-runner"]
