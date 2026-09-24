#!/bin/bash

openssl genrsa -out development/webhook-config/ca.key 2048 2>/dev/null

openssl req -new -x509 -days 365 -key development/webhook-config/ca.key \
  -subj "/C=DE/CN=authz-server" -config development/webhook-config/openssl.conf \
  -out development/webhook-config/ca.crt 2>/dev/null

openssl req -newkey rsa:2048 -nodes -keyout development/webhook-config/tls.key \
  -subj "/C=DE/CN=authz-server" \
  -out development/webhook-config/tls.csr 2>/dev/null

openssl x509 -req \
  -days 365 \
  -extfile <(printf "subjectAltName=IP:10.96.86.219") \
  -in development/webhook-config/tls.csr \
  -CA development/webhook-config/ca.crt -CAkey development/webhook-config/ca.key -CAcreateserial \
  -out development/webhook-config/tls.crt 2>/dev/null

rm development/webhook-config/*.csr
