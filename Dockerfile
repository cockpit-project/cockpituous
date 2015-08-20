FROM fedora:21
MAINTAINER "Stef Walter" <stefw@redhat.com>

RUN yum -y update
RUN yum -y install git

RUN mkdir -p /build /usr/local/bin
COPY build-* /usr/local/bin/
