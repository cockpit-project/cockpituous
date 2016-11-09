FROM cockpit/infra-base
MAINTAINER "Stef Walter" <stefw@redhat.com>

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y update && \
    dnf -y install \
bind-utils \
bodhi-client \
bzip2 \
copr-cli \
debian-keyring \
dpkg \
dpkg-dev \
expect \
fedpkg \
fontconfig \
fpaste \
freetype \
git \
gnupg \
hardlink \
krb5-workstation \
nc \
npm tar \
pbuilder \
psmisc \
python \
python-irclib \
reprepro \
which \
yum-utils \
    && \
    npm -g install \
aws4 \
aws-sign2 \
bl \
caseless \
concat-stream \
debug \
extend \
har-validator \
isexe \
is-stream \
isstream \
is-typedarray \
jsonfile \
klaw \
mime-types \
path-is-absolute \
phantomjs-prebuilt \
pinkie-promise \
stringstream \
throttleit \
tough-cookie \
yauzl \
    && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

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
