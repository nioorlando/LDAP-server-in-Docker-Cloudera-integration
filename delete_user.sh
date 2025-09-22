#!/usr/bin/env bash
set -euo pipefail

# Delete a user and remove from the trainees group
# Usage:
#   ./delete_user.sh <cn>
#
CN_VAL="${1:-}"
if [[ -z "${CN_VAL}" ]]; then
  echo "Usage: $0 <cn>" >&2
  exit 1
fi

LDAP_HOST="${LDAP_HOST:-localhost}"
LDAP_PORT="${LDAP_PORT:-389}"
BASE_DN="${BASE_DN:-dc=training,dc=local}"
ADMIN_DN="${ADMIN_DN:-cn=admin,dc=training,dc=local}"
ADMIN_PASS="${ADMIN_PASS:-admin_password}"
GROUP_DN="${GROUP_DN:-cn=trainees,ou=groups,${BASE_DN}}"
USER_DN="cn=${CN_VAL},ou=people,${BASE_DN}"

# Remove from group (ignore error if not present)
TMP_MOD="$(mktemp)"
cat > "${TMP_MOD}" <<EOF
dn: ${GROUP_DN}
changetype: modify
delete: member
member: ${USER_DN}
EOF

echo "-> Removing ${CN_VAL} from group ${GROUP_DN} (if present)"
docker exec -i openldap ldapmodify -x -H "ldap://${LDAP_HOST}:${LDAP_PORT}"   -D "${ADMIN_DN}" -w "${ADMIN_PASS}" -f - < "${TMP_MOD}" || true
rm -f "${TMP_MOD}"

# Delete the user
echo "-> Deleting user DN=${USER_DN}"
docker exec -i openldap ldapdelete -x -H "ldap://${LDAP_HOST}:${LDAP_PORT}"   -D "${ADMIN_DN}" -w "${ADMIN_PASS}" "${USER_DN}"

echo "✅ User '${CN_VAL}' deleted."
