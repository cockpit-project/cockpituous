FROM fedora:30
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update && \
    dnf -y install \
        american-fuzzy-lop \
        chromium-headless \
        curl \
        expect \
        gcc \
        gcc-c++ \
        git \
        gnupg \
        jq \
        libguestfs-tools \
        libguestfs-xfs \
        libappstream-glib \
        libvirt \
        libvirt-client \
        libvirt-python3 \
        make \
        nc \
        net-tools \
        npm \
        openssl \
        origin-clients \
        psmisc \
        procps-ng \
        python \
        python3 \
        python3-pika \
        rpm-build \
        rpmdevtools \
        sed \
        tar \
        virt-install \
        wget \
        zanata-client && \
    curl -s -o /tmp/cockpit.spec https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec && \
    sed -i 's/%{npm-version:.*}/0/' /tmp/cockpit.spec && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

COPY cockpit-tasks install-service webhook github_handler.py /usr/local/bin/

RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user && \
    mkdir -p /home/user/.ssh && mkdir -p /usr/local/bin && \
    mkdir -p /build /secrets /cache/images /cache/github /build/libvirt/qemu && \
    printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n' >/home/user/.gitconfig && \
    ln -s /cache/images /build/images && \
    ln -s /cache/images /build/virt-builder && \
    ln -s /cache/github /build/github && \
    ln -s /tmp /build/tmp && \
    mkdir -p /home/user/.config /home/user/.ssh /home/user/.rhel && \
    ln -snf /secrets/ssh-config /home/user/.ssh/config && \
    ln -snf /secrets/image-stores /home/user/.config/image-stores && \
    ln -snf /secrets/codecov-token /home/user/.config/codecov-token && \
    ln -snf /secrets/rhel-login /home/user/.rhel/login && \
    ln -snf /secrets/rhel-password /home/user/.rhel/pass && \
    ln -snf /secrets/zanata.ini /home/user/.config/zanata.ini && \
    ln -snf /secrets/lorax-test-env.sh /home/user/.config/lorax-test-env && \
    ln -snf /run/secrets/webhook/.config--github-token /home/user/.config/github-token && \
    chmod g=u /etc/passwd && \
    chmod -R ugo+w /build /secrets /cache /home/user

# Prevent us from screwing around with KVM settings in the container
RUN touch /etc/modprobe.d/kvm-amd.conf && touch /etc/modprobe.d/kvm-intel.conf

ENV LANG=C.UTF-8 \
    LIBGUESTFS_BACKEND=direct \
    XDG_CACHE_HOME=/build \
    HOME=/home/user \
    TMPDIR=/tmp \
    TEMPDIR=/tmp \
    TEST_DATA=/build \
    TEST_PUBLISH=

VOLUME /cache

USER user
WORKDIR /build
CMD ["/usr/local/bin/cockpit-tasks", "--publish", "$TEST_PUBLISH", "--verbose"]

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root IMAGE /bin/bash -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tests container
LABEL RUN /usr/bin/docker run -ti --rm --privileged --uts=host --volume=/var/lib/cockpit-secrets/tasks:/secrets:ro --volume=/var/cache/cockpit-tests:/cache:rw IMAGE /bin/bash -i
