#!/bin/bash

# fetch root CA of the local OCI registry
openssl s_client -connect oci-registry-docker-registry.registry.svc.cluster.local:443 -showcerts </dev/null 2>/dev/null| openssl x509 -outform PEM > registry-ca.pem

# configure OS to trust this RootCA
sudo cp registry-ca.pem /usr/local/share/ca-certificates/local-oci-registry_root_ca.crt
sudo update-ca-certificates

# push ctf to local OCI registry
ocm transfer ctf --overwrite /tmp/transport.ctf oci://oci-registry-docker-registry.registry.svc.cluster.local/platform-mesh