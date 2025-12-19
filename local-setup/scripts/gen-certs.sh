#!/bin/bash

openssl genrsa -out local-setup/webhook-config/ca.key 2048 2>/dev/null

openssl req -new -x509 -days 365 -key local-setup/webhook-config/ca.key \
  -subj "/C=DE/CN=authz-server" -config local-setup/webhook-config/openssl.conf \
  -out local-setup/webhook-config/ca.crt 2>/dev/null

openssl req -newkey rsa:2048 -nodes -keyout local-setup/webhook-config/tls.key \
  -subj "/C=DE/CN=authz-server" \
  -out local-setup/webhook-config/tls.csr 2>/dev/null

openssl x509 -req \
  -days 365 \
  -extfile <(printf "subjectAltName=IP:10.96.86.219") \
  -in local-setup/webhook-config/tls.csr \
  -CA local-setup/webhook-config/ca.crt -CAkey local-setup/webhook-config/ca.key -CAcreateserial \
  -out local-setup/webhook-config/tls.crt 2>/dev/null

rm local-setup/webhook-config/*.csr
