# LDAP for Cloudera (Docker‑based OpenLDAP + phpLDAPadmin)

This repository contains a **ready‑to‑use, Docker‑based OpenLDAP** setup for integrating external authentication with **Cloudera Manager** (training or lab environments). It also includes **TLS trust steps** and **CM configuration**.

## Contents
- [`ldap_docker_setup.md`](ldap_docker_setup.md) — full step‑by‑step for OpenLDAP + TLS + CM integration
- `compose/` — docker‑compose file and init LDIFs (you can add your own)
- `certs/` — place your Root CA here if you use custom CA (optional)
- `images/` — screenshots (optional)

## Quick Start
```bash
# 1) Bring up LDAP (OpenLDAP + phpLDAPadmin)
docker compose -f compose/docker-compose.yml up -d

# 2) (Optional) Trust Root CA on CM host for LDAPS
sudo cp certs/rootCA.crt /etc/pki/ca-trust/source/anchors/ldap-rootCA.crt
sudo update-ca-trust extract

# 3) Verify LDAPS bind using the service account
LDAPTLS_CACERT=certs/rootCA.crt ldapwhoami -x -H ldaps://ldap.local:636   -D "uid=ldapbind,ou=service,dc=training,dc=local" -w "(password)"
```

## What you get
- OpenLDAP preconfigured for **BaseDN `dc=training,dc=local`**
- Example **service account** (`uid=ldapbind`) and **trainee users** (`trainee01..15`)
- Example **group** `cn=trainees,ou=groups,...`
- End‑to‑end **Cloudera Manager external authentication** configuration (LDAPS)

See the full guide in [`ldap_docker_setup.md`](ldap_docker_setup.md).

## 
```text
cloudera-ldap-docker/
├─ README.md                # rename dari README_LDAP.md kalau mau jadi root readme
├─ ldap_docker_setup.md
├─ compose/
│  └─ docker-compose.yml
├─ ldif/
│  ├─ 00-base.ldif
│  ├─ 10-service-account.ldif
│  ├─ 20-trainees-group.ldif
│  └─ 30-users-sample.ldif
├─ scripts/
│  └─ rootCA.crt   
├─ certs/
│  └─ README.md          # opsional; plus ldap.crt/ldap.key jika pakai LDAPS
└─ images/
```
