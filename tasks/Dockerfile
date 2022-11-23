FROM fedora:37
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update && \
    dnf -y install \
        'dnf-command(builddep)' \
        byobu \
        chromium-headless \
        curl \
        dbus-glib \
        diffstat \
        expect \
        fedpkg \
        firefox \
        fpaste \
        gcc-c++ \
        genisoimage \
        git \
        git-lfs \
        gnupg \
        gobject-introspection-devel \
        google-noto-cjk-fonts-common \
        intltool \
        jq \
        lcov \
        libappstream-glib \
        libtool \
        libvirt-daemon-driver-storage-core \
        libvirt-daemon-driver-qemu \
        libvirt-client \
        libvirt-python3 \
        libXt \
        nc \
        net-tools \
        nodejs-devel \
        npm \
        origin-clients \
        psmisc \
        procps-ng \
        python3 \
        python3-build \
        python3-flake8 \
        python3-pika \
        python3-pillow \
        python3-wheel \
        qemu-kvm-core \
        rpm-build \
        rpmdevtools \
        rsync \
        socat \
        strace \
        tar \
        vim-enhanced \
        virt-install \
        wget && \
    curl -o /tmp/cockpit.spec -s https://raw.githubusercontent.com/cockpit-project/cockpit/main/tools/cockpit.spec | \
    dnf -y builddep /tmp/cockpit.spec && \
    rm /tmp/cockpit.spec && \
    dnf clean all

COPY cockpit-tasks install-service webhook github_handler.py /usr/local/bin/

RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user --home-dir /work && \
    mkdir -p /usr/local/bin /secrets /cache/images /cache/github && \
    mkdir -p /work/.config /work/.config/cockpit-dev /work/.ssh /work/.cache /work/.rhel && \
    printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n[cockpit "bots"]\n\timages-data-dir = /cache/images\n' >/work/.gitconfig && \
    ln -snf /secrets/codecov-token /work/.config/codecov-token && \
    ln -snf /secrets/s3-keys /work/.config/cockpit-dev/s3-keys && \
    ln -snf /run/secrets/webhook/.config--github-token /work/.config/github-token && \
    chmod g=u /etc/passwd && \
    chmod -R ugo+w /cache /secrets /cache /work && \
    chown -R user:user /cache /work && \
    printf '[libdefaults]\ndefault_ccache_name = FILE:/tmp/krb5.ccache\n' > /etc/krb5.conf.d/0_file_ccache && \
    echo 'user ALL=NOPASSWD: /usr/bin/chmod 666 /dev/kvm' > /etc/sudoers.d/user-fix-kvm

ENV LANG=C.UTF-8 \
    TEST_OVERLAY_DIR=/tmp

VOLUME /cache/images

USER user
WORKDIR /work
CMD ["/usr/local/bin/cockpit-tasks", "--verbose"]
