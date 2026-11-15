#!/usr/bin/env bash
# Cloud Monitoring alerts (FRD §7.4: errors logged centrally, alerts on
# public menu error rates and downtime). M13.
#
#   ALERT_EMAIL=ops@eazysuvai.com MENU_HOST=menu.eazysuvai.com SAMPLE_SLUG=eazysuvai-demo \
#     ops/monitoring.sh <project-id> [--apply]
#
# Creates: an email notification channel; a log-based metric for function
# errors; alert policies for (1) function errors, (2) renderMenu 5xx rate,
# (3) renderMenu p95 latency; and an uptime check on a sample menu with its
# alert. Policies live in ops/monitoring/*.json with placeholders filled here.
source "$(dirname "$0")/lib.sh"
parse_common "$@"

: "${ALERT_EMAIL:?Set ALERT_EMAIL}"
: "${MENU_HOST:?Set MENU_HOST (the public menu domain, no https://)}"
: "${SAMPLE_SLUG:?Set SAMPLE_SLUG (a published menu kept for monitoring)}"
DIR="$(cd "$(dirname "$0")/monitoring" && pwd)"

if [[ "$APPLY" == true ]]; then
  CHANNEL="$(gcloud beta monitoring channels create --project="$PROJECT" \
    --display-name="EazySuvai ops" --type=email \
    --channel-labels=email_address="$ALERT_EMAIL" --format='value(name)')"
else
  CHANNEL="projects/$PROJECT/notificationChannels/<new>"
  echo "+ gcloud beta monitoring channels create --type=email --channel-labels=email_address=$ALERT_EMAIL"
fi

run gcloud logging metrics create function_errors --project="$PROJECT" \
  --description="Cloud Functions log entries at ERROR or above (M13)" \
  --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'

run gcloud monitoring uptime create "Public menu: $SAMPLE_SLUG" --project="$PROJECT" \
  --resource-type=uptime-url --resource-labels="host=$MENU_HOST,project_id=$PROJECT" \
  --path="/$SAMPLE_SLUG" --protocol=https --period=1 --timeout=10 \
  --matcher-content="</html>" --matcher-type=contains-string \
  --regions=asia-pacific,europe,usa-oregon

for policy in "$DIR"/*.json; do
  OUT="$(mktemp)"
  sed -e "s|__CHANNEL__|$CHANNEL|g" -e "s|__HOST__|$MENU_HOST|g" "$policy" > "$OUT"
  run gcloud alpha monitoring policies create --project="$PROJECT" --policy-from-file="$OUT"
done
echo "# Check: Monitoring → Alerting shows 4 policies; Monitoring → Uptime checks shows the menu."
