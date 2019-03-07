FROM cockpit/infra-base
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

# whois-mkpasswd conflicts with expect and we don't need it
RUN dnf -y update && \
    dnf -y remove whois-mkpasswd && \
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
    sed -i 's/%{npm-version:.*}/0/' /tmp/cockpit.spec && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all && \
    mkdir -p /usr/local/bin /home/user /build/ && \
    chmod g=u /etc/passwd && \
    chmod -R ugo+w /build /home/user

ADD * /usr/local/bin/

# HACK: Working around Node.js screwing around with stdio
ENV NODE_PATH /usr/bin/node.real
RUN mv /usr/bin/node /usr/bin/node.real
ADD node-stdio-wrapper /usr/bin/node

VOLUME /home/user /build /run/secrets/release
WORKDIR /build
USER user
ENTRYPOINT ["/usr/local/bin/release-runner"]
