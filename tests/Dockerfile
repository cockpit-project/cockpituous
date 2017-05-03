FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec
RUN dnf -y update && \
    dnf -y install \
        bind-utils \
        bodhi-client \
        bzip2 \
        copr-cli \
        curl \
        expect \
        fedpkg \
        fontconfig \
        freetype \
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
        rpm-build \
        rpmdevtools \
        sed \
        selinux-policy-devel \
        sudo \
        tar \
        virt-install \
        && \
    npm -g install phantomjs-prebuilt && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

RUN mkdir -p /usr/local/bin /home/user /build /build/tmp /secrets /images
ADD cockpit-tests install-service vm-prep network-cockpit.xml /usr/local/bin/

RUN usermod -a -G mock user
RUN echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN echo "config_opts['basedir'] = '/build/mock/'" >> /etc/mock/site-defaults.cfg
RUN printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n' >/home/user/.gitconfig && \
    ln -s /images /build/images && \
    mkdir -p /home/user/.config /home/user/.ssh && \
    ln -snf /secrets/ssh-config /home/user/.ssh/config && \
    ln -snf /secrets/github-token /home/user/.config/github-token && \
    git clone https://github.com/cockpit-project/cockpit /build/cockpit && \
    cd /build/cockpit && npm install && \
    chown -R user /build /secrets /images /home/user

# Prevent us from screwing around with KVM settings in the container
RUN touch /etc/modprobe.d/kvm-amd.conf && touch /etc/modprobe.d/kvm-intel.conf

# Continue to work with a host defined cockpit1 network if necessary
RUN chmod -v u+s /usr/libexec/qemu-bridge-helper && echo 'allow cockpit1' >> /etc/qemu/bridge.conf

ENV XDG_CACHE_HOME /build/tmp
ENV XDG_CONFIG_HOME /build/tmp
ENV TMPDIR /build/tmp
ENV TEMP /build/tmp
ENV TEMPDIR /build/tmp
ENV TEST_DATA /build

VOLUME /secrets
VOLUME /images

USER user
WORKDIR /build
ENTRYPOINT ["/usr/local/bin/cockpit-tests"]
CMD ["--publish=fedorapeople.org", "--verbose"]

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root --entrypoint=/bin/bash IMAGE -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tests container
LABEL RUN /usr/bin/docker run -ti --rm --privileged --uts=host --volume=/var/lib/cockpit-tests/secrets:/secrets:ro --volume=/var/lib/cockpit-tests/images:/images:rw IMAGE /bin/bash -i
