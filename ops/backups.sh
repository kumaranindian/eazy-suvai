#!/usr/bin/env bash
# Firestore backups (FRD §7.4: daily full, continuous point-in-time recovery,
# 35-day retention; RPO 1 hour, RTO 4 hours). M13.
#
#   ops/backups.sh <project-id> [--apply]
#
# - Point-in-time recovery: any minute of the last 7 days (the Firestore
#   maximum), well inside the 1-hour RPO.
# - A daily managed backup kept 5 weeks (35 days). Data purged by M12 leaves
#   the backups within 35 days, as the privacy policy says.
# - A weekly export of everything to a Cloud Storage bucket in the same
#   region (asia-south1), kept 35 days by a lifecycle rule: an independent
#   copy outside the database service.
source "$(dirname "$0")/lib.sh"
parse_common "$@"

LOCATION="asia-south1"
BUCKET="gs://${PROJECT}-firestore-exports"

run gcloud firestore databases update --project="$PROJECT" --database='(default)' --enable-pitr
run gcloud firestore backups schedules create --project="$PROJECT" --database='(default)' \
  --recurrence=daily --retention=5w

run gcloud storage buckets create "$BUCKET" --project="$PROJECT" --location="$LOCATION" \
  --uniform-bucket-level-access --public-access-prevention
LIFECYCLE="$(mktemp)"
cat > "$LIFECYCLE" <<'JSON'
{ "rule": [{ "action": { "type": "Delete" }, "condition": { "age": 35 } }] }
JSON
run gcloud storage buckets update "$BUCKET" --lifecycle-file="$LIFECYCLE"

# Weekly export with Cloud Scheduler calling the Firestore export API as the
# default service account (needs roles/datastore.importExportAdmin and
# storage write on the bucket).
SA="${PROJECT}@appspot.gserviceaccount.com"
run gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" \
  --role=roles/datastore.importExportAdmin --condition=None
run gcloud storage buckets add-iam-policy-binding "$BUCKET" --member="serviceAccount:$SA" \
  --role=roles/storage.objectAdmin
run gcloud scheduler jobs create http firestore-weekly-export --project="$PROJECT" \
  --location="$LOCATION" --schedule="0 3 * * 0" --time-zone="Asia/Kolkata" \
  --uri="https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default):exportDocuments" \
  --http-method=POST --oauth-service-account-email="$SA" \
  --message-body="{\"outputUriPrefix\":\"${BUCKET}\"}"

echo "# Check: gcloud firestore databases describe --project=$PROJECT --database='(default)' (pointInTimeRecoveryEnablement)"
echo "#        gcloud firestore backups schedules list --project=$PROJECT --database='(default)'"
