FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN dnf -y install git yum-utils npm rpm-build curl libvirt-client openssl rpmdevtools libguestfs-tools \
         rpm-build krb5-workstation python-lxml expect selinux-policy-devel tar bzip2 python bind-utils \
         nc gnupg freetype fontconfig krb5-workstation expect psmisc mock libvirt \
         libvirt-python sudo python-libguestfs net-tools virt-install \
         kernel grubby libguestfs-xfs \
         koji bodhi-client copr-cli fedpkg; \
         dnf clean all
RUN npm -g install phantomjs-prebuilt

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec
RUN yum-builddep -y /tmp/cockpit.spec; dnf clean all

RUN mkdir -p /usr/local/bin /home/user /build
ADD cockpit-verify /usr/local/bin/

RUN chown -R user /build /home/user
RUN usermod -a -G mock user
RUN echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN echo "config_opts['basedir'] = '/build/mock/'" >> /etc/mock/site-defaults.cfg
RUN chmod -v u+s /usr/libexec/qemu-bridge-helper && echo 'allow cockpit1' >> /etc/qemu/bridge.conf

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
