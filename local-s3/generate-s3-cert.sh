#!/bin/sh
# Generate local S3 image server certificate
set -eux

ROOTDIR="$(realpath -m "$0"/../../)"
OPENSSL_CNF="$ROOTDIR/tasks/credentials/openssl.cnf"

openssl req -new -newkey rsa:2048 -nodes -keyout s3-server.key -out s3-server.csr \
    -subj '/O=Cockpit/OU=Cockpituous/CN=cockpit-tests' \
    -extensions server_ca_extensions -reqexts server_ca_extensions \
    -config "$OPENSSL_CNF"
openssl x509 -req -days 365000 -in s3-server.csr -out s3-server.pem \
    -CA ../ca.pem -CAkey ../ca.key \
    -set_serial $(date +%s) \
    -extensions server_ca_extensions -extfile "$OPENSSL_CNF"
rm s3-server.csr
