#!/bin/sh

# Certain commands cannot be run in Dockerfile including pbuilder run them here

DEPENDS="debhelper dh-autoreconf autoconf automake intltool zlib1g-dev libkrb5-dev
         libxslt1-dev libkeyutils-dev libglib2.0-dev libsystemd-dev libpolkit-agent-1-dev libpcp3-dev
         libjson-glib-dev libpam0g-dev libpcp-import1-dev libpcp-pmda3-dev xsltproc xmlto docbook-xsl
         glib-networking npm openssh-client"

JESSIE_DEPENDS="$DEPENDS nodejs libssh-dev"

sudo pbuilder create --distribution jessie --basetgz /var/cache/pbuilder/jessie.tgz \
    --extrapackages "$JESSIE_DEPENDS"

UNSTABLE_DEPENDS="$DEPENDS nodejs-legacy libssh-dev"

sudo pbuilder create --distribution unstable --basetgz /var/cache/pbuilder/unstable.tgz \
     --extrapackages "$UNSTABLE_DEPENDS"
