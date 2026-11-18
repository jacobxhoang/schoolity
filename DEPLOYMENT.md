# Deploy Schoolity on Vercel

1. Import `jacobxhoang/schoolity` into Vercel. Select **SvelteKit**, root directory `./`, and Node.js **22.x**. Leave output-directory settings at their defaults. The repository supplies the build command.
2. Add an **Upstash Redis** database from Vercel Marketplace and connect it to this project. Enable the integration for the environments you plan to deploy. Review the provider's pricing before provisioning.
3. Ensure these **server-only** environment variables exist:
   - `UPSTASH_REDIS_REST_URL`
   - `UPSTASH_REDIS_REST_TOKEN` (the read/write token)
   - `SCHOOLITY_REMEMBER_KEY` — a 32-byte standard-base64 key used to encrypt opt-in saved sign-ins. Generate one with `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"` or `openssl rand -base64 32`. Use the same value in every environment that shares a store; rotating it invalidates existing saved sign-ins.

   Existing integrations using `KV_REST_API_URL` and `KV_REST_API_TOKEN` are also supported. Never prefix these variables with `PUBLIC_` or put credentials into GitHub.

4. Use separate databases or different `SCHOOLITY_STORE_PREFIX` values for Production and Preview (for example, `schoolity-production` and `schoolity-preview`). If Production and Preview share a database, use the same `SCHOOLITY_REMEMBER_KEY` so saved sign-ins remain readable across deployments.
5. Deploy or redeploy after connecting storage. Do not set localhost `HOST`, `PORT`, or `ORIGIN` on Vercel. The HTTPS deployment hostname is used for same-origin requests and secure session cookies.

The official Vercel adapter is selected when `VERCEL=1`. Local builds continue using the Node adapter, so `npm start` still works. No Vercel CLI or account credentials are committed.

## Sessions and limits

Vercel instances share sessions, saved sign-ins, and login-attempt limits through Redis. Sessions follow the district token lifetime, capped at 30 days; signing out deletes the session and any saved sign-in, plus every session linked to it. When a student selects **Keep me signed in**, the server stores an AES-256-GCM encrypted copy of the school login for up to 30 days so an expired district session can renew. Passwords are never stored in browser storage. Login limits are tracked per username and client address for interactive sign-in, and per saved sign-in for automatic renewal, so one school network bucket does not lock out every student. Access tokens are held in the shared store, which requires HTTPS. Local development defaults to expiring in-memory storage. On Vercel, missing or unavailable shared storage blocks sign-in, and a missing `SCHOOLITY_REMEMBER_KEY` blocks saved sign-in (503) without affecting session-only sign-in.

Document downloads above 4 MB are rejected with a message directing students to StudentVUE, keeping responses below Vercel's function response-size limit. Large files are not saved to disk. Function duration is configured for 60 seconds; the individual district requests retain their 15-second timeouts.

## Verify after deployment

- Anonymous visits show sign-in, and signed-out API requests return 401.
- Sign in with an actual district account; open grades, schedule, and documents.
- Refresh the browser and verify the session survives. Download a small document.
- Verify **Keep me signed in** is off by default. Select it, confirm the session renews after the district session expires or the browser is restarted, then sign out and verify the saved sign-in cookie and linked server session are gone.
- Sign out and verify the workspace and server session are cleared.
- Confirm `SCHOOLITY_REMEMBER_KEY` is set in Production and Preview; without it, saved sign-in returns 503 while ordinary sign-in still works.
- Preview and Production use separate storage namespaces.

Automated tests cover the local/shared store behavior, revocation, fail-closed configuration, and download authorization. Actual Vercel/Upstash provisioning and a live district login require deployment verification.

The Vercel output was generated locally on Windows using a test-only directory-junction workaround for Windows symlink permissions. Vercel's Linux build environment uses the unmodified official adapter. This packaging check does not replace a real hosted deployment check.

References: [SvelteKit Vercel adapter](https://svelte.dev/docs/kit/adapter-vercel), [Upstash REST API](https://upstash.com/docs/redis/features/restapi), [Vercel function limits](https://vercel.com/docs/functions/limitations).

Sign-in uses a persistent, HTTP-only, Secure (on HTTPS), SameSite=Lax cookie. Refreshing, closing a tab, and returning from another site preserve a valid session. Cookie and storage expiry match the district-provided token lifetime, capped at 30 days; absent or invalid expiry falls back to 30 minutes. District revocation still requires signing in again. Passwords are not saved unless the student selects **Keep me signed in**, in which case an encrypted copy is kept server-side for up to 30 days and removed on sign-out. Existing sessions need a fresh sign-in to receive the new cookie settings.

Mail attachments use `GetSynergyMailGetAttachment` (`data.attachmentXML`) after checking the attachment against its parent message in the signed-in inbox. JSON and single-field XML base64 envelopes are supported; DTD/entity declarations are rejected. Downloads share the same no-store, attachment-disposition, filename and file-size protections as student documents. The [JSON API catalog](https://github.com/StudentVue/docs/blob/master/JSON-API.md) documents the method; exact district-specific request/response compatibility still requires a live attachment check.
