# LDAP Setup for Cloudera Manager (Docker)

This document sets up **OpenLDAP (osixia/openldap)** and **phpLDAPadmin** with optional **LDAPS**, then integrates it with **Cloudera Manager** external authentication.

---

## 1) Docker Compose — OpenLDAP + phpLDAPadmin

Create `compose/docker-compose.yml`:
```yaml
version: "3.8"
services:
  openldap:
    image: osixia/openldap:1.5.0
    container_name: openldap
    environment:
      LDAP_ORGANISATION: "Training LDAP"
      LDAP_DOMAIN: "training.local"
      LDAP_BASE_DN: "dc=training,dc=local"
      LDAP_ADMIN_PASSWORD: "(password_admin_ldap)"
      LDAP_CONFIG_PASSWORD: "(password_config)"
      LDAP_READONLY_USER: "false"
      LDAP_TLS: "true"
      LDAP_TLS_CRT_FILENAME: "ldap.crt"
      LDAP_TLS_KEY_FILENAME: "ldap.key"
      LDAP_TLS_CA_CRT_FILENAME: "rootCA.crt"
      LDAP_TLS_ENFORCE: "false"
      LDAP_TLS_VERIFY_CLIENT: "try"
    ports:
      - "389:389"
      - "636:636"
    volumes:
      - ./data/slapd/database:/var/lib/ldap
      - ./data/slapd/config:/etc/ldap/slapd.d
      - ./certs:/container/service/slapd/assets/certs:ro
      - ./ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom:ro
    restart: unless-stopped

  phpldapadmin:
    image: osixia/phpldapadmin:0.9.0
    container_name: phpldapadmin
    environment:
      PHPLDAPADMIN_HTTPS: "false"
      PHPLDAPADMIN_LDAP_HOSTS: "openldap"
    ports:
      - "8080:80"
    depends_on:
      - openldap
    restart: unless-stopped
```

> Put your **self‑signed or lab CA** in `./certs/` as `rootCA.crt`, plus `ldap.crt`/`ldap.key` with SAN including `ldap.local` and/or the host IP.

Bootstrap initial entries via LDIFs: place LDIF files under `ldif/` (examples below).

---

## 2) Example LDIFs — Base structure, service account, users & group

`ldif/00-base.ldif`:
```ldif
dn: ou=service,dc=training,dc=local
objectClass: organizationalUnit
ou: service

dn: ou=people,dc=training,dc=local
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=training,dc=local
objectClass: organizationalUnit
ou: groups
```

`ldif/10-service-account.ldif`:
```ldif
dn: uid=ldapbind,ou=service,dc=training,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: ldapbind
sn: ldapbind
uid: ldapbind
userPassword: (hash_passwordnya)  # generate with slappasswd
```

`ldif/20-trainees-group.ldif`:
```ldif
dn: cn=trainees,ou=groups,dc=training,dc=local
objectClass: groupOfNames
cn: trainees
member: cn=trainee01,ou=people,dc=training,dc=local
member: cn=trainee02,ou=people,dc=training,dc=local
# ... tambahkan member lainnya
```

`ldif/30-users-sample.ldif` (repeat as needed):
```ldif
dn: cn=trainee01,ou=people,dc=training,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: trainee01
sn: trainee01
uid: trainee01
mail: trainee01@training.local
userPassword: (hash_passwordnya)
```

Generate password hash:
```bash
docker run --rm --entrypoint /usr/sbin/slappasswd osixia/openldap:1.5.0 -s "(passwordnya)"
```

Bring up the stack:
```bash
docker compose -f compose/docker-compose.yml up -d
```

---

## 3) Trust Root CA on Cloudera Manager host (for LDAPS)

Copy your CA to the OS trust store:
```bash
export ROOTCA=~/ldap-docker/certs/rootCA.crt
sudo cp "$ROOTCA" /etc/pki/ca-trust/source/anchors/ldap-rootCA.crt
sudo update-ca-trust extract
```

Also import into the **Java** truststore used by CM:
```bash
sudo keytool -importcert -alias ldap-ca   -file "$ROOTCA"   -keystore /etc/pki/java/cacerts -storepass changeit -noprompt
```

Add hosts mapping (if you use `ldap.local`):
```bash
echo "(ip_ldap_server) ldap.local" | sudo tee -a /etc/hosts
```

Verify LDAPS bind:
```bash
LDAPTLS_CACERT="$ROOTCA" ldapwhoami -x -H ldaps://ldap.local:636   -D "uid=ldapbind,ou=service,dc=training,dc=local" -w "(passwordnya)"
```

---

## 4) Check LDAP entries

Verify users and group:
```bash
LDAPTLS_CACERT="$ROOTCA" ldapsearch -x -H ldaps://ldap.local:636   -D "uid=ldapbind,ou=service,dc=training,dc=local" -w "(passwordnya)"   -b "ou=people,dc=training,dc=local" "(uid=trainee01)" dn

LDAPTLS_CACERT="$ROOTCA" ldapsearch -x -H ldaps://ldap.local:636   -D "uid=ldapbind,ou=service,dc=training,dc=local" -w "(passwordnya)"   -b "ou=groups,dc=training,dc=local" "(cn=trainees)" dn member
```

---

## 5) Configure External Authentication in Cloudera Manager

CM UI → **Administration → Settings → External Authentication**:
- Authentication Backend Order → **External then Database**
- External Authentication Type → **LDAP**
- LDAP URL → `ldaps://ldap.local:636`
- LDAP Bind User DN → `uid=ldapbind,ou=service,dc=training,dc=local`
- LDAP Bind Password → `(passwordnya)`
- LDAP User Search Filter → `(uid={0})`
- LDAP User Search Base → `dc=training,dc=local`
- LDAP Group Search Filter → `(member={0})`
- LDAP Group Search Base → `dc=training,dc=local`
- LDAP Distinguished Name Pattern → *(kosongkan)*
- Active Directory Domain → *(kosong)*

Apply & restart CM:
```bash
sudo systemctl restart cloudera-scm-server
```

Test from CM “External Authentication Test”:
- Username: `trainee01`
- Password: `(passwordnya)`

Expected: **authenticated successfully**.

---

## 6) Map LDAP Group to CM Role

CM UI → **Administration → Users & Roles → LDAP/PAM Groups → Add Mapping**
- LDAP/PAM Group: `trainees` (or DN `cn=trainees,ou=groups,dc=training,dc=local`)
- Roles: **Operator** (recommended for training)

Save.

---

## 7) Common Operations (manage users/groups)

Delete a user:
```bash
docker exec -i openldap ldapdelete -x   -H ldap://localhost:389   -D "cn=admin,dc=training,dc=local" -w "(password_admin_ldap)"   "cn=trainee05,ou=people,dc=training,dc=local"
```

Remove from group:
```bash
cat <<EOF | docker exec -i openldap ldapmodify -x   -H ldap://localhost:389   -D "cn=admin,dc=training,dc=local" -w "(password_admin_ldap)"
dn: cn=trainees,ou=groups,dc=training,dc=local
changetype: modify
delete: member
member: cn=trainee05,ou=people,dc=training,dc=local
EOF
```

Rename (modrdn) a user:
```bash
docker exec -i openldap ldapmodrdn -x   -H ldap://localhost:389   -D "cn=admin,dc=training,dc=local" -w "(password_admin_ldap)"   "cn=trainee05,ou=people,dc=training,dc=local"   "cn=trainee20"
# Update group membership accordingly
```

Add a new user (generate hash and add LDIF, then add to group):
```bash
USER_HASH=$(docker run --rm --entrypoint /usr/sbin/slappasswd osixia/openldap:1.5.0 -s "(passwordnya)")

cat <<EOF | docker exec -i openldap ldapadd -x   -H ldap://localhost:389   -D "cn=admin,dc=training,dc=local" -w "(password_admin_ldap)"
dn: cn=trainee16,ou=people,dc=training,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: trainee16
sn: trainee16
uid: trainee16
mail: trainee16@training.local
userPassword: ${USER_HASH}
EOF

cat <<EOF | docker exec -i openldap ldapmodify -x   -H ldap://localhost:389   -D "cn=admin,dc=training,dc=local" -w "(password_admin_ldap)"
dn: cn=trainees,ou=groups,dc=training,dc=local
changetype: modify
add: member
member: cn=trainee16,ou=people,dc=training,dc=local
EOF
```

---

## 8) Result
- ✅ OpenLDAP + LDAPS running via Docker
- ✅ CA trusted by OS & CM’s Java
- ✅ CM authenticates external users via LDAP
- ✅ Group‑to‑Role mapping applied (e.g., `trainees` → Operator)

---
