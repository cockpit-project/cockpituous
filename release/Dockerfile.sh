#!/bin/sh

# Certain commands cannot be run in Dockerfile including pbuilder run them here

BUILD_DEPENDS="debhelper dh-autoreconf autoconf automake intltool libssh-dev libssl-dev zlib1g-dev libkrb5-dev
               libxslt1-dev libkeyutils-dev libglib2.0-dev libsystemd-dev libpolkit-agent-1-dev libpcp3-dev
               libjson-glib-dev libpam0g-dev libpcp-import1-dev libpcp-pmda3-dev xsltproc xmlto docbook-xsl
               glib-networking nodejs-legacy npm openssh-client"

sudo pbuilder create --distribution unstable --extrapackages "$BUILD_DEPENDS"
