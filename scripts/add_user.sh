#!/usr/bin/env bash
set -euo pipefail

# Add a user to OpenLDAP (osixia/openldap) and include them in the 'trainees' group.
# Usage:
#   ./add_user.sh <uid> <password> [cn] [mail]
#
# Examples:
#   ./add_user.sh trainee16 'P@ssw0rd!' 'trainee16' 'trainee16@training.local'
#
# Requirements:
# - Docker is running
# - Container name: openldap
# - BaseDN: dc=training,dc=local
# - Admin DN: cn=admin,dc=training,dc=local
#
# Notes:
# - This script generates an SSHA password hash using slappasswd inside the image.
# - It then creates the user entry and adds the user to the 'trainees' group.
#
UID_VAL="${1:-}"
PASS_PLAIN="${2:-}"
CN_VAL="${3:-$1}"
MAIL_VAL="${4:-${1}@training.local}"

if [[ -z "${UID_VAL}" || -z "${PASS_PLAIN}" ]]; then
  echo "Usage: $0 <uid> <password> [cn] [mail]" >&2
  exit 1
fi

LDAP_HOST="${LDAP_HOST:-localhost}"               # host where openldap listens (inside docker compose it's 'openldap')
LDAP_PORT="${LDAP_PORT:-389}"
BASE_DN="${BASE_DN:-dc=training,dc=local}"
ADMIN_DN="${ADMIN_DN:-cn=admin,dc=training,dc=local}"
ADMIN_PASS="${ADMIN_PASS:-admin_password}"        # CHANGE: export ADMIN_PASS env or edit here
GROUP_DN="${GROUP_DN:-cn=trainees,ou=groups,${BASE_DN}}"

# Generate SSHA hash using the same image used by the container
HASH=$(docker run --rm --entrypoint /usr/sbin/slappasswd osixia/openldap:1.5.0 -s "${PASS_PLAIN}")

# Create user LDIF (inetOrgPerson)
TMP_LDIF="$(mktemp)"
cat > "${TMP_LDIF}" <<EOF
dn: cn=${CN_VAL},ou=people,${BASE_DN}
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: ${CN_VAL}
sn: ${CN_VAL}
uid: ${UID_VAL}
mail: ${MAIL_VAL}
userPassword: ${HASH}
EOF

echo "-> Adding user ${CN_VAL} (uid=${UID_VAL})"
docker exec -i openldap ldapadd -x -H "ldap://${LDAP_HOST}:${LDAP_PORT}"   -D "${ADMIN_DN}" -w "${ADMIN_PASS}" -f - < "${TMP_LDIF}"

rm -f "${TMP_LDIF}"

# Add user to trainees group
TMP_MOD="$(mktemp)"
cat > "${TMP_MOD}" <<EOF
dn: ${GROUP_DN}
changetype: modify
add: member
member: cn=${CN_VAL},ou=people,${BASE_DN}
EOF

echo "-> Adding ${CN_VAL} to group ${GROUP_DN}"
docker exec -i openldap ldapmodify -x -H "ldap://${LDAP_HOST}:${LDAP_PORT}"   -D "${ADMIN_DN}" -w "${ADMIN_PASS}" -f - < "${TMP_MOD}"

rm -f "${TMP_MOD}"

echo "✅ Done. User '${UID_VAL}' created and added to 'trainees'."
