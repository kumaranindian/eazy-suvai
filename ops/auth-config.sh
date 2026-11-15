#!/usr/bin/env bash
# Firebase Authentication / Identity Platform settings for a real project
# (M13; FRD §7.2). Needs Identity Platform enabled on the project.
#
#   APP_DOMAIN=app.eazysuvai.com ADMIN_DOMAIN=admin.eazysuvai.com \
#     ops/auth-config.sh <project-id> [--apply]
#
# Sets, through the Identity Toolkit admin API:
#   - branded verification and password-reset emails (ops/auth/*.html:
#     sender name, reply-to, subject, HTML body with %LINK%);
#   - TOTP multi-factor authentication (admins must enrol, FR-084);
#   - the password policy (8+ characters, enforced; breached passwords are
#     refused by the app's check, M01) and email enumeration protection;
#   - authorized domains for the app and admin sites.
# If the API refuses the template body (some projects only allow it with a
# custom SMTP server), set the sender, subject and reply-to here and paste
# the body in the console: Authentication → Templates.
source "$(dirname "$0")/lib.sh"
parse_common "$@"

: "${APP_DOMAIN:?Set APP_DOMAIN (owner dashboard domain)}"
: "${ADMIN_DOMAIN:?Set ADMIN_DOMAIN (admin dashboard domain)}"
DIR="$(cd "$(dirname "$0")/auth" && pwd)"

BODY="$(node -e '
const fs = require("fs");
const [dir, project, app, admin] = process.argv.slice(1);
const tpl = (file, subject) => ({
  senderDisplayName: "EazySuvai",
  replyTo: "support@eazysuvai.com",
  subject,
  body: fs.readFileSync(`${dir}/${file}`, "utf8"),
  bodyFormat: "HTML",
});
console.log(JSON.stringify({
  notification: { sendEmail: {
    verifyEmailTemplate: tpl("verify-email.html", "Confirm your email for EazySuvai"),
    resetPasswordTemplate: tpl("reset-password.html", "Reset your EazySuvai password"),
  } },
  mfa: { state: "ENABLED", providerConfigs: [{ state: "ENABLED", totpProviderConfig: { adjacentIntervals: 5 } }] },
  passwordPolicyConfig: {
    passwordPolicyEnforcementState: "ENFORCE",
    passwordPolicyVersions: [{ customStrengthOptions: { minPasswordLength: 8, maxPasswordLength: 4096 } }],
  },
  emailPrivacyConfig: { enableImprovedEmailPrivacy: true },
  authorizedDomains: [`${project}.firebaseapp.com`, `${project}.web.app`, app, admin],
}));' "$DIR" "$PROJECT" "$APP_DOMAIN" "$ADMIN_DOMAIN")"

MASK="notification.sendEmail.verifyEmailTemplate,notification.sendEmail.resetPasswordTemplate,mfa,passwordPolicyConfig,emailPrivacyConfig,authorizedDomains"
URL="https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT}/config?updateMask=${MASK}"

if [[ "$APPLY" == true ]]; then
  TOKEN="$(gcloud auth print-access-token)"
  curl -sS --fail-with-body -X PATCH "$URL" \
    -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: $PROJECT" \
    -H "Content-Type: application/json" -d "$BODY" | head -c 2000
  echo
else
  echo "+ curl -X PATCH $URL"
  echo "$BODY" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);for(const t of Object.values(j.notification.sendEmail))t.body=`<${t.body.length} characters>`;console.log(JSON.stringify(j,null,2))})'
fi
