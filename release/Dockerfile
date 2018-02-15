FROM cockpit/infra-base
LABEL maintainer="'Stef Walter' <stefw@redhat.com>"

ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec

RUN dnf -y update && \
    dnf -y install \
bind-utils \
bodhi-client \
bzip2 \
debian-keyring \
devscripts \
dpkg \
dpkg-dev \
expect \
fontconfig \
fpaste \
freetype \
git \
gnupg \
hardlink \
krb5-workstation \
nc \
npm tar \
psmisc \
python \
python-irclib \
reprepro \
rpm-build \
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
pinkie-promise \
stringstream \
throttleit \
tough-cookie \
yauzl \
    && \
    dnf -y install --enablerepo=updates-testing fedpkg koji copr-cli && \
    dnf -y install 'dnf-command(builddep)' && \
    dnf -y builddep /tmp/cockpit.spec && \
    dnf clean all

RUN mkdir -p /usr/local/bin /home/user /build/rpmbuild
ADD * /usr/local/bin/

RUN chown -R user /build /home/user

VOLUME /home/user /build
WORKDIR /build
USER user
ENTRYPOINT ["/usr/local/bin/release-runner"]
