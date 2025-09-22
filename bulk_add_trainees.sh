#!/usr/bin/env bash
set -euo pipefail

# Bulk add trainee users with the same password.
# Usage:
#   ./bulk_add_trainees.sh 01 15 'P@ssw0rd!'
#
START_NUM="${1:-}"
END_NUM="${2:-}"
PASS="${3:-}"

if [[ -z "${START_NUM}" || -z "${END_NUM}" || -z "${PASS}" ]]; then
  echo "Usage: $0 <start_num> <end_num> <password>" >&2
  echo "Example: $0 1 15 'P@ssw0rd!'" >&2
  exit 1
fi

pad() { printf "%02d" "$1"; }

for i in $(seq "${START_NUM}" "${END_NUM}"); do
  n=$(pad "$i")
  uid="trainee${n}"
  cn="${uid}"
  mail="${uid}@training.local"
  echo "==> Creating ${uid}"
  UID_VAL="${uid}" PASS_PLAIN="${PASS}" CN_VAL="${cn}" MAIL_VAL="${mail}"     bash "$(dirname "$0")/add_user.sh" "${uid}" "${PASS}" "${cn}" "${mail}"
done

echo "✅ Bulk create finished."
