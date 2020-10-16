FROM fedora:latest
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

# whois-mkpasswd conflicts with expect and we don't need it
RUN dnf -y update && \
    dnf -y install \
bind-utils \
bodhi-client \
bzip2 \
copr-cli \
debian-keyring \
devscripts \
dpkg \
dpkg-dev \
expect \
findutils \
fontconfig \
fedpkg \
fpaste \
freetype \
git \
gnupg \
hardlink \
koji \
krb5-workstation \
nc \
npm \
psmisc \
rpm-build \
rsync \
sassc \
tar \
which \
dnf-utils \
    && \
    dnf -y install 'dnf-command(builddep)' && \
    curl https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec | sed 's/%{npm-version:.*}/0/' > /tmp/cockpit.spec && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

# krb: default in Fedora is KEYRING:, which doesn't work in containers
RUN mkdir -p /usr/local/bin /build/ && \
    printf '[libdefaults]\ndefault_ccache_name = FILE:/tmp/krb5.ccache\n' > /etc/krb5.conf.d/0_file_ccache && \
    groupadd -g 1111 -r user && useradd -r -g user -u 1111 user && \
    mkdir -p /home/user/.config /home/user/.ssh && \
    printf '[user]\n\tname = Cockpit Project\n\temail=cockpituous@gmail.com\n' > /home/user/.gitconfig && \
    chown -R user:user /home/user && \
    chmod -R ugo+w /build /home/user && \
    chmod g=u /etc/passwd

ADD * /usr/local/bin/

# HACK: Working around Node.js screwing around with stdio
ENV NODE_PATH=/usr/bin/node.real LANG=C.UTF-8
RUN mv /usr/bin/node /usr/bin/node.real
ADD node-stdio-wrapper /usr/bin/node

USER user
WORKDIR /build
ENTRYPOINT ["/usr/local/bin/release-runner"]
