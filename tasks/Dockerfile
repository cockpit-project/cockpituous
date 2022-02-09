FROM fedora:35
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
        git \
        git-lfs \
        gnupg \
        intltool \
        jq \
        libappstream-glib \
        libvirt-daemon-kvm \
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
        python3-pyflakes \
        python3 \
        python3-pycodestyle \
        python3-pika \
        python3-pillow \
        rpm-build \
        rpmdevtools \
        rsync \
        sassc \
        socat \
        strace \
        tar \
        vim-enhanced \
        virt-install \
        wget && \
    curl -s https://raw.githubusercontent.com/cockpit-project/cockpit/main/tools/cockpit.spec.in | \
    sed 's/@[A-Z_]*@/0/g' > /tmp/cockpit.spec && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf -y install \
        audit-libs-devel \
        libtool \
        gettext-devel \
        gtk3-devel \
        gtk-doc \
        gtk3-devel-docs \
        glib2-doc \
        gobject-introspection-devel \
        glade-devel \
        libgnomekbd-devel \
        libxklavier-devel \
        make \
        pango-devel \
        python3-devel \
        rpm-devel \
        libarchive-devel \
        libtimezonemap-devel \
        gdk-pixbuf2-devel \
        libxml2 \
        gsettings-desktop-schemas \
        desktop-file-utils && \
    dnf clean all

COPY cockpit-tasks install-service webhook github_handler.py /usr/local/bin/

RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user --home-dir /work && \
    mkdir -p /usr/local/bin /secrets /cache/images /cache/github && \
    mkdir -p /work/.config /work/.config/cockpit-dev /work/.ssh /work/.cache /work/.rhel && \
    printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n[cockpit "bots"]\n\timages-data-dir = /cache/images\n' >/work/.gitconfig && \
    ln -snf /secrets/ssh-config /work/.ssh/config && \
    ln -snf /secrets/image-stores /work/.config/image-stores && \
    ln -snf /secrets/codecov-token /work/.config/codecov-token && \
    ln -snf /secrets/rhel-login /work/.rhel/login && \
    ln -snf /secrets/rhel-password /work/.rhel/pass && \
    ln -snf /secrets/s3-keys /work/.config/cockpit-dev/s3-keys && \
    ln -snf /secrets/lorax-test-env.sh /work/.config/lorax-test-env && \
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
CMD ["/usr/local/bin/cockpit-tasks", "--publish", "$TEST_PUBLISH", "--verbose"]

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root IMAGE /bin/bash -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tests container
LABEL RUN /usr/bin/docker run -ti --rm --volume=/var/lib/cockpit-secrets/tasks:/secrets:ro --volume=/var/cache/cockpit-tasks/images:/cache/images:rw IMAGE /bin/bash -i

# Start a container in the background; attach to it with "docker exec -it <name> byobu"
LABEL DEV /usr/bin/docker run -d --volume=/var/cache/cockpit-tasks/images:/cache/images:rw IMAGE sleep infinity
