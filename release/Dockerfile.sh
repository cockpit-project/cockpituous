#!/bin/sh

# Certain commands cannot be run in Dockerfile including pbuilder run them here

DEPENDS="debhelper dpkg-dev dh-autoreconf dh-systemd
         autoconf automake intltool zlib1g-dev libkrb5-dev
         libxslt1-dev libkeyutils-dev libglib2.0-dev libsystemd-dev libpolkit-agent-1-dev
         libjson-glib-dev libpam0g-dev xsltproc xmlto docbook-xsl
         glib-networking openssh-client libssh-dev"

JESSIE_DEPENDS="$DEPENDS  libpcp3-dev libpcp-import1-dev libpcp-pmda3-dev"

sudo pbuilder create --distribution jessie --mirror http://deb.debian.org/debian \
    --basetgz /var/cache/pbuilder/jessie.tgz --extrapackages "$JESSIE_DEPENDS"

UNSTABLE_DEPENDS="$DEPENDS"

sudo pbuilder create --distribution unstable --mirror http://deb.debian.org/debian \
    --basetgz /var/cache/pbuilder/unstable.tgz --extrapackages "$UNSTABLE_DEPENDS"
