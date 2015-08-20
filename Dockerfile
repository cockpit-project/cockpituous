FROM fedora:21
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN yum -y update
RUN yum -y install git yum-utils npm tar bzip2 fedpkg copr-cli

# Install cockpit build dependencies
ADD https://raw.githubusercontent.com/cockpit-project/cockpit/master/tools/cockpit.spec /tmp/cockpit.spec
RUN yum-builddep -y /tmp/cockpit.spec

RUN mkdir -p /build /usr/local/bin
COPY build-* /usr/local/bin/
