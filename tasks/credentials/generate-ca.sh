#!/bin/sh -ex
# Generate CA

openssl req -config $(dirname $0)/openssl.cnf -x509  -newkey rsa:2048 -days 365000 -out ca.pem -keyout ca.key -outform PEM -subj /O=Cockpit/OU=Cockpituous/CN=CA/ -nodes
