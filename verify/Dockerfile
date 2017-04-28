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

RUN mkdir -p /usr/local/bin /home/user /build
ADD cockpit-verify vm-prep network-cockpit.xml /usr/local/bin/

RUN chown -R user /build /home/user
RUN usermod -a -G mock user
RUN echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN echo "config_opts['basedir'] = '/build/mock/'" >> /etc/mock/site-defaults.cfg

# Prevent us from screwing around with KVM settings in the container
RUN touch /etc/modprobe.d/kvm-amd.conf && touch /etc/modprobe.d/kvm-intel.conf

ENV TEST_IMAGES_RHEL http://file.rdu.redhat.com/~swalter/images/
ENV XDG_CACHE_HOME /build/tmp
ENV XDG_CONFIG_HOME /build/tmp
ENV TMPDIR /build/tmp
ENV TEMP /build/tmp
ENV TEMPDIR /build/tmp

VOLUME /home/user
VOLUME /build

USER user
WORKDIR /build
ENTRYPOINT ["/usr/local/bin/cockpit-verify"]
CMD ["--publish=fedorapeople.org", "--verbose"]
