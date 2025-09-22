# Certificates for LDAP (LDAPS)

This folder should contain the TLS certificates for OpenLDAP.

## Files required
- `rootCA.crt` → Root Certificate Authority (CA)  
- `ldap.crt` → Server certificate signed by the Root CA  
- `ldap.key` → Private key for the server certificate  

## Generate self-signed certificates (lab use)

```bash
# Generate Root CA key + cert
openssl req -x509 -new -nodes -days 3650 -sha256 \
  -subj "/CN=Training Root CA" \
  -keyout rootCA.key -out rootCA.crt

# Generate LDAP server key + CSR
openssl req -new -nodes -sha256 \
  -subj "/CN=ldap.local" \
  -keyout ldap.key -out ldap.csr

# Sign server cert with Root CA
openssl x509 -req -in ldap.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial \
  -out ldap.crt -days 3650 -sha256 \
  -extfile <(echo "subjectAltName=DNS:ldap.local,IP:127.0.0.1")
```
