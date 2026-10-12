#!/usr/bin/env bash
# The two store reviewer allow-lists that verify_identity reads (M13):
#
#   store-reviewer-phones  test numbers in E.164 form, one per line (+201000000001)
#   store-reviewer-uids    account ids, comma or newline separated
#
# Both are created EMPTY, which means nobody is let through. The functions
# read them with their runtime service account, so it is granted
# secretAccessor on each. Every command is idempotent.
#
#   bash firebase/ops/reviewer-secrets.sh            # create and grant
#   bash firebase/ops/reviewer-secrets.sh --list     # show the versions
#
# To open a review, add a version holding the test numbers:
#   printf '+201000000001\n+201000000002\n' | \
#     gcloud secrets versions add store-reviewer-phones --data-file=- --project=own-hub
# To close it, add a blank version (a lone newline; empty is refused):
#   printf '\n' | gcloud secrets versions add store-reviewer-phones --data-file=- --project=own-hub

set -euo pipefail

PROJECT="${PROJECT:-own-hub}"
SECRETS=(store-reviewer-phones store-reviewer-uids)

if [ "${1:-}" = "--list" ]; then
  for secret in "${SECRETS[@]}"; do
    echo "== $secret"
    gcloud secrets versions list "$secret" --project="$PROJECT"
  done
  exit 0
fi

# Gen 2 functions run as the default compute service account unless one is
# set in the function's options. Override with SERVICE_ACCOUNT=... if so.
if [ -z "${SERVICE_ACCOUNT:-}" ]; then
  number=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')
  SERVICE_ACCOUNT="${number}-compute@developer.gserviceaccount.com"
fi

for secret in "${SECRETS[@]}"; do
  if ! gcloud secrets describe "$secret" --project="$PROJECT" >/dev/null 2>&1; then
    gcloud secrets create "$secret" --replication-policy=user-managed \
      --locations=europe-west3 --project="$PROJECT"
  fi
  # Secret Manager refuses an empty payload; a lone newline parses as an empty
  # list (store.parse_reviewer_*), so nobody is let through.
  if ! gcloud secrets versions list "$secret" --project="$PROJECT" \
      --filter=state=enabled --format='value(name)' | grep -q .; then
    printf '\n' | gcloud secrets versions add "$secret" --data-file=- --project="$PROJECT"
  fi
  gcloud secrets add-iam-policy-binding "$secret" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role=roles/secretmanager.secretAccessor \
    --project="$PROJECT" >/dev/null
  echo "ok $secret (readable by $SERVICE_ACCOUNT)"
done
