#!/bin/sh -ex
# Generate AMQP server certs

OPENSSL_CONF=$(dirname $0)/../openssl.cnf

touch index.txt
echo 01 > serial
mkdir certs

ln -s ../ca.key
ln ../ca.pem

openssl genrsa -out amqp-server.key 2048
openssl req -new -key amqp-server.key -out req.pem -outform PEM -subj /CN=cockpit-amqp-server/O=amqp-server/ -nodes
openssl ca  -config $OPENSSL_CONF  -in req.pem -out amqp-server.pem -notext -batch -extensions server_ca_extensions
rm -f req.pem

openssl genrsa -out amqp-client.key 2048
openssl req -new -key amqp-client.key -out req.pem -outform PEM -subj /CN=cockpit-amqp/O=client/ -nodes
openssl ca -config $OPENSSL_CONF -in req.pem -out amqp-client.pem -notext -batch -extensions client_ca_extensions
rm -f req.pem

rm -f index.txt* serial serial.old ca.key
rm -rf certs
