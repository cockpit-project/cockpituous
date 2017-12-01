FROM cockpit/infra-base
LABEL maintainer='"Stef Walter" <stefw@redhat.com>'

RUN dnf -y update && \
    dnf -y install \
        american-fuzzy-lop \
        bind-utils \
        bodhi-client \
        bzip2 \
        copr-cli \
        curl \
        expect \
        fedpkg \
        fontconfig \
        freetype \
        gettext \
        git \
        gnupg \
        grubby \
        hardlink \
        kernel \
        koji \
        krb5-workstation \
        libguestfs-tools \
        libguestfs-xfs \
        libvirt \
        libvirt-client \
        libvirt-python \
        mock \
        nc \
        net-tools \
        npm \
        openssl \
        psmisc \
        python \
        python-libguestfs \
        python-lxml \
        python-scikit-learn \
        rpm-build \
        rpmdevtools \
        sed \
        selinux-policy-devel \
        sudo \
        tar \
        virt-install \
        zanata-client && \
    dnf -y install chromium-headless --enablerepo=updates-testing && \
    npm -g install phantomjs-prebuilt && \
    curl -s -o /tmp/cockpit.spec https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

COPY cockpit-tests install-service /usr/local/bin/

RUN mkdir -p /usr/local/bin /home/user /build /secrets /cache/images /cache/github /build/libvirt/qemu && \
    usermod -a -G mock user && \
    echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    echo "config_opts['basedir'] = '/build/mock/'" >> /etc/mock/site-defaults.cfg && \
    printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n' >/home/user/.gitconfig && \
    ln -s /cache/images /build/images && \
    ln -s /cache/images /build/virt-builder && \
    ln -s /cache/images /build/libvirt/qemu/log && \
    ln -s /cache/github /build/github && \
    ln -s /tmp /build/tmp && \
    mkdir -p /home/user/.config /home/user/.ssh /home/user/.rhel && \
    ln -snf /secrets/ssh-config /home/user/.ssh/config && \
    ln -snf /secrets/github-token /home/user/.config/github-token && \
    ln -snf /secrets/image-stores /home/user/.config/image-stores && \
    ln -snf /secrets/rhel-login /home/user/.rhel/login && \
    ln -snf /secrets/rhel-password /home/user/.rhel/pass && \
    ln -snf /secrets/zanata.ini /home/user/.config/zanata.ini && \
    git clone https://github.com/cockpit-project/cockpit /build/cockpit && \
    cd /build/cockpit && npm install && \
    chown -R user /build /secrets /cache /home/user

# Prevent us from screwing around with KVM settings in the container
RUN touch /etc/modprobe.d/kvm-amd.conf && touch /etc/modprobe.d/kvm-intel.conf

# Continue to work with a host defined cockpit1 network if necessary
RUN chmod -v u+s /usr/libexec/qemu-bridge-helper && echo 'allow cockpit1' >> /etc/qemu/bridge.conf

ENV LIBGUESTFS_BACKEND=direct \
    XDG_CACHE_HOME=/build \
    TMPDIR=/tmp \
    TEMPDIR=/tmp \
    TEST_DATA=/build \
    TEST_PUBLISH=

VOLUME /secrets /cache /tmp

USER user
WORKDIR /build
CMD ["/usr/local/bin/cockpit-tests", "--publish", "$TEST_PUBLISH", "--verbose"]

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root IMAGE /bin/bash -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tests container
LABEL RUN /usr/bin/docker run -ti --rm --privileged --uts=host --volume=/var/lib/cockpit-tests/secrets:/secrets:ro --volume=/var/cache/cockpit-tests:/cache:rw IMAGE /bin/bash -i
