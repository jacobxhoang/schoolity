# Closed-app notification service — groundwork, not activated

The current released iOS app uses local notifications with opportunistic background checks. This server groundwork does not activate remote notifications by itself. The iOS app still needs APNs device registration, secure enrollment/revocation UI, and a push-enabled signed build. Those changes remain pending compatible Apple Developer credentials. Normal iOS grade and record requests continue going directly to StudentVUE.

## Required access

A `.p12` signing identity and `.mobileprovision` bought from a signing service do not necessarily authorize an APNs provider. The app identifier, provisioning profile, APNs topic, and provider key must belong to a compatible Apple Developer team. Obtain a push-enabled profile and an APNs `.p8` provider key, its Key ID, and Team ID from the account owner, or use an Apple Developer account you control. Re-signing under a different app identifier or stripping the push entitlement prevents delivery. Do not commit signing files, passwords, APNs keys, or student credentials.

## Implemented server pieces

- `GET /api/push`: public capability discovery, returning `available: false` until configured.
- `POST /api/push`: bounded same-origin JSON registration, status, and deletion. Native enrollment must send the service's Origin header and a random 32-byte base64url management secret in `Authorization: Bearer ...`. The random subscription ID is another 32-byte base64url value. Only an authenticated school login can establish a subscription. Registration accepts `action: register`, `id`, `device` (APNs token hex), `environment` (`development` or `production`), `username`, and `password`.
- Status/deletion use `action: status` or `action: delete` and the subscription `id`, with the management secret. They never return credentials, tokens, or grade contents.
- `GET /api/push/check`: scheduler endpoint, requiring `Authorization: Bearer <CRON_SECRET>`. It processes one due subscription per call, with a five-minute polling interval per student and bounded backoff. A larger installation requires more worker invocations or a dedicated queue worker.
- APNs HTTP/2 alert pushes use an ES256 provider token. These are visible alerts, not silent pushes that would need to relaunch a force-quit app. Delivery remains best effort and depends on the device's notification settings.

Credentials, district tokens, device tokens, and grade flags are encrypted together with AES-256-GCM under a separate server encryption key. Management secrets are hashed. Records expire after 30 days unless a user explicitly re-enrolls. First observations of a reporting period are silent; newly graded scores, including zero, trigger one alert or a summary for multiple assignments. Repeat checks, regrades, excluded work, and hypothetical scores do not repeat alerts. Invalid APNs device tokens remove the subscription. Rejected school credentials pause checks and clear the stored password/token. Atomic leases and compare-and-set updates protect concurrent checks and revocation. A notification already in flight to Apple cannot be recalled.

## Configuration after compatible Apple access is available

Use the existing shared Upstash store or another supported Redis REST store. Set these **server-only** variables in the chosen host's secret manager:

| Variable                        | Value                                              |
| ------------------------------- | -------------------------------------------------- |
| `SCHOOLITY_PUSH_ENABLED`        | `true` only after the full setup is verified       |
| `SCHOOLITY_PUSH_ENCRYPTION_KEY` | Separate random 32-byte standard-base64 key        |
| `SCHOOLITY_APNS_PRIVATE_KEY`    | APNs `.p8` PEM, with real newlines or escaped `\n` |
| `SCHOOLITY_APNS_KEY_ID`         | Apple Key ID                                       |
| `SCHOOLITY_APNS_TEAM_ID`        | Apple Team ID                                      |
| `SCHOOLITY_APNS_TOPIC`          | The signed app's exact bundle identifier           |
| `CRON_SECRET`                   | Random secret of at least 32 characters            |

Generate secrets locally with `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`. Keep production and preview stores/keys separate. Changing encryption keys invalidates stored subscriptions; coordinate rotation and remove old encrypted records. Enrollment must explicitly explain that the notification service retains an encrypted school sign-in while closed-app alerts are enabled, and disabling/signing out must revoke it.

Configure an authenticated external scheduler to call `/api/push/check` frequently enough for the number of enrolled students. No schedule is activated in this repository. Vercel Hobby cron runs only daily; frequent checks need an external scheduler or an appropriate hosting plan. Never put the scheduler secret in a URL or browser code.

## Remaining activation checks

1. Inspect the actual provisioning profile's `aps-environment`, application identifier, and team; obtain a matching APNs provider key.
2. Implement and test native token registration and protected opt-in enrollment, with safe disable/sign-out revocation and duplicate suppression between local and remote alerts.
3. Configure server secrets and the scheduler. Test the APNs sandbox with a signed physical iPhone.
4. Verify delivery after force-quitting, revoked device tokens, password changes, consent revocation, offline devices, and notification preview settings. Match sandbox/production to the signed profile, not to a guessed build type.

Automated tests currently cover encryption, management authorization, silent baselines, zero scores, retries, concurrency, revocation during district requests, invalid device tokens, rejected credentials, scheduler authentication, and ES256 signature verification. No live APNs or third-party signing account has been used.
