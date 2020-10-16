FROM fedora:32
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update && \
    dnf -y install \
        'dnf-command(builddep)' \
        american-fuzzy-lop \
        chromium-headless \
        curl \
        dbus-glib \
        expect \
        gcc \
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
        make \
        nc \
        net-tools \
        npm \
        openssl \
        origin-clients \
        psmisc \
        procps-ng \
        python3-pyflakes \
        python \
        python3 \
        python3-pycodestyle \
        python3-pika \
        rpm-build \
        rpmdevtools \
        rsync \
        sassc \
        sed \
        tar \
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

RUN groupadd -g 1111 -r user && useradd -r -g user -u 1111 user && \
    mkdir -p /usr/local/bin /secrets /cache/images /cache/github && \
    mkdir -p /home/user/.config /home/user/.ssh /home/user/.cache /home/user/.rhel && \
    printf '[user]\n\t\nemail = cockpituous@cockpit-project.org\n\tname = Cockpituous\n[cockpit "bots"]\n\timages-data-dir = /cache/images\n' >/home/user/.gitconfig && \
    ln -snf /secrets/ssh-config /home/user/.ssh/config && \
    ln -snf /secrets/image-stores /home/user/.config/image-stores && \
    ln -snf /secrets/codecov-token /home/user/.config/codecov-token && \
    ln -snf /secrets/rhel-login /home/user/.rhel/login && \
    ln -snf /secrets/rhel-password /home/user/.rhel/pass && \
    ln -snf /secrets/lorax-test-env.sh /home/user/.config/lorax-test-env && \
    ln -snf /run/secrets/webhook/.config--github-token /home/user/.config/github-token && \
    chmod g=u /etc/passwd && \
    chmod -R ugo+w /cache /secrets /cache /home/user && \
    ln -s /app/bin/firefox /usr/bin/firefox

# Prevent us from screwing around with KVM settings in the container
RUN touch /etc/modprobe.d/kvm-amd.conf && touch /etc/modprobe.d/kvm-intel.conf

ENV LANG=C.UTF-8 \
    HOME=/home/user \
    TEST_OVERLAY_DIR=/tmp

VOLUME /cache/images

USER user
WORKDIR /home/user
CMD ["/usr/local/bin/cockpit-tasks", "--publish", "$TEST_PUBLISH", "--verbose"]

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root IMAGE /bin/bash -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tests container
LABEL RUN /usr/bin/docker run -ti --rm --privileged --uts=host --volume=/var/lib/cockpit-secrets/tasks:/secrets:ro --volume=/var/cache/cockpit-tasks/images:/cache/images:rw IMAGE /bin/bash -i
