#!/usr/bin/env bash
# Test restore (FRD §7.4: restore tested every quarter). M13.
#
#   ops/restore-test.sh <project-id> [--apply]
#
# Restores the newest daily backup into a NEW database (never over the
# live one), compares document counts of the main collections with the
# live database, records the timings against the 4-hour RTO, and deletes
# the restored database. Write the result in docs/launch/runbook.md.
source "$(dirname "$0")/lib.sh"
parse_common "$@"

LOCATION="asia-south1"
TARGET="restore-test-$(date +%Y%m%d)"

if [[ "$APPLY" == true ]]; then
  BACKUP="$(gcloud firestore backups list --project="$PROJECT" --location="$LOCATION" \
    --format='value(name)' --sort-by=~snapshotTime --limit=1)"
  [[ -n "$BACKUP" ]] || { echo "No backup found. Run ops/backups.sh first and wait a day." >&2; exit 1; }
else
  BACKUP="projects/$PROJECT/locations/$LOCATION/backups/<newest>"
fi

START=$(date +%s)
run gcloud firestore databases restore --project="$PROJECT" \
  --source-backup="$BACKUP" --destination-database="$TARGET"
END=$(date +%s)
echo "# restore took $((END - START)) s (RTO 4 h = 14400 s)"

# Compare counts (Application Default Credentials; read-only on both).
run node "$(dirname "$0")/compare-counts.mjs" --project "$PROJECT" --database "$TARGET"

run gcloud firestore databases delete --project="$PROJECT" --database="$TARGET" --quiet
