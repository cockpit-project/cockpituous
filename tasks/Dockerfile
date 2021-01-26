FROM fedora:33
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

# HACK: chromium 88 crashes with some keyDown commands: https://bugs.chromium.org/p/chromium/issues/detail?id=1170634
RUN dnf -y update && \
    dnf -y install \
        'dnf-command(builddep)' \
        american-fuzzy-lop \
        byobu \
        https://kojipkgs.fedoraproject.org//packages/chromium/87.0.4280.141/1.fc33/x86_64/chromium-common-87.0.4280.141-1.fc33.x86_64.rpm \
        https://kojipkgs.fedoraproject.org//packages/chromium/87.0.4280.141/1.fc33/x86_64/chromium-headless-87.0.4280.141-1.fc33.x86_64.rpm \
        curl \
        dbus-glib \
        diffstat \
        expect \
        fedpkg \
        fpaste \
        gcc-c++ \
        git \
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
        npm \
        origin-clients \
        psmisc \
        procps-ng \
        python3-pyflakes \
        python3 \
        python3-pycodestyle \
        python3-pika \
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
    curl -s -o /tmp/cockpit.spec https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec && \
    sed -i 's/%{npm-version:.*}/0/' /tmp/cockpit.spec && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

# Install nightly firefox, as neither the betas nor Fedora distro builds have the remote debugger
RUN curl --location 'https://download.mozilla.org/?product=firefox-nightly-latest-ssl&os=linux64&lang=en-US' | \
        tar -C /usr/local/lib/ -xj && \
    ln -s /usr/local/lib/firefox/firefox /usr/local/bin/

COPY cockpit-tasks install-service webhook github_handler.py /usr/local/bin/

RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user --home-dir /work && \
    mkdir -p /usr/local/bin /secrets /cache/images /cache/github && \
    mkdir -p /work/.config /work/.ssh /work/.cache /work/.rhel && \
    printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n[cockpit "bots"]\n\timages-data-dir = /cache/images\n' >/work/.gitconfig && \
    ln -snf /secrets/ssh-config /work/.ssh/config && \
    ln -snf /secrets/image-stores /work/.config/image-stores && \
    ln -snf /secrets/codecov-token /work/.config/codecov-token && \
    ln -snf /secrets/rhel-login /work/.rhel/login && \
    ln -snf /secrets/rhel-password /work/.rhel/pass && \
    ln -snf /secrets/lorax-test-env.sh /work/.config/lorax-test-env && \
    ln -snf /run/secrets/webhook/.config--github-token /work/.config/github-token && \
    chmod g=u /etc/passwd && \
    chmod -R ugo+w /cache /secrets /cache /work && \
    chown -R user:user /cache /work && \
    ln -s /app/bin/firefox /usr/bin/firefox && \
    printf '[libdefaults]\ndefault_ccache_name = FILE:/tmp/krb5.ccache\n' > /etc/krb5.conf.d/0_file_ccache

# Prevent us from screwing around with KVM settings in the container
RUN touch /etc/modprobe.d/kvm-amd.conf && touch /etc/modprobe.d/kvm-intel.conf

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
