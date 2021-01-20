#!/bin/bash -ex
# Generate image server certificate

SAN="DNS:*.apps.ci.centos.org,DNS:*.apps.ocp.ci.centos.org,DNS:*.e2e.bos.redhat.com,DNS:*.cockpit-project.org,DNS:cockpit-tests"
openssl req -new -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj '/O=Cockpit/OU=Cockpituous/CN=cockpit-tests' -extensions SAN -reqexts SAN -config <(cat /etc/pki/tls/openssl.cnf; printf "\n[SAN]\nsubjectAltName=$SAN")
openssl x509 -req -days 365000 -in server.csr -CA ../ca.pem -CAkey ../ca.key -set_serial $(date +%s) -extensions SAN -extfile <(printf "\n[SAN]\nsubjectAltName=$SAN") -out server.pem
rm server.csr
