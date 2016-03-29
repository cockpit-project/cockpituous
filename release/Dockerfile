FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y install git yum-utils npm tar bzip2 fedpkg copr-cli python python-irclib fpaste bind-utils nc gnupg freetype fontconfig krb5-workstation bodhi-client expect psmisc dpkg dpkg-dev pbuilder reprepro debian-keyring
RUN yum-builddep -y /tmp/cockpit.spec
RUN npm install -g phantomjs-prebuilt

RUN mkdir -p /usr/local/bin /home/user /build/rpmbuild
ADD * /usr/local/bin/

RUN chown -R user /build /home/user

RUN printf "user ALL=(root) NOPASSWD: /usr/sbin/pbuilder\n" > /etc/sudoers.d/allow-pbuilder

# HACK remount devpts with newinstance in a hook so that the pbuilder chroot
# can access it
RUN mkdir -p /etc/pbuilder/hooks && \
    echo -e \#\!"/bin/bash\n" \
            "mount none \"\$BUILDPLACE/dev/pts\"" \
            "-oremount,noexec,nosuid,gid=5,mode=620,newinstance,ptmxmode=0666" \
            > /etc/pbuilder/hooks/D10remountdevpts && \
    chmod +x /etc/pbuilder/hooks/D10remountdevpts

ENV RELEASE_SINK fedorapeople.org
VOLUME /home/user
VOLUME /build
WORKDIR /build
USER user
CMD ["dummy-arg"]
