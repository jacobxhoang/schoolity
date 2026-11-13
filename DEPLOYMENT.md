# Deploy Schoolity on Vercel

1. Import `verityhoangjacob67/schoolity` into Vercel. Select **SvelteKit**, root directory `./`, and Node.js **22.x**. Leave output-directory settings at their defaults. The repository supplies the build command.
2. Add an **Upstash Redis** database from Vercel Marketplace and connect it to this project. Enable the integration for the environments you plan to deploy. Review the provider's pricing before provisioning.
3. Ensure these **server-only** environment variables exist:
   - `UPSTASH_REDIS_REST_URL`
   - `UPSTASH_REDIS_REST_TOKEN` (the read/write token)

   Existing integrations using `KV_REST_API_URL` and `KV_REST_API_TOKEN` are also supported. Never prefix these variables with `PUBLIC_` or put credentials into GitHub.
4. Use separate databases or different `SCHOOLITY_STORE_PREFIX` values for Production and Preview (for example, `schoolity-production` and `schoolity-preview`).
5. Deploy or redeploy after connecting storage. Do not set localhost `HOST`, `PORT`, or `ORIGIN` on Vercel. The HTTPS deployment hostname is used for same-origin requests and secure session cookies.

The official Vercel adapter is selected when `VERCEL=1`. Local builds continue using the Node adapter, so `npm start` still works. No Vercel CLI or account credentials are committed.

## Sessions and limits

Vercel instances share sessions and login-attempt limits through Redis. Sessions expire after at most 30 minutes; signing out deletes the session. Passwords are never stored. Access tokens are held in the shared store, which requires HTTPS. Local development defaults to expiring in-memory storage. On Vercel, missing or unavailable shared storage blocks sign-in rather than falling back to unreliable instance memory.

Document downloads above 4 MB are rejected with a message directing students to StudentVUE, keeping responses below Vercel's function response-size limit. Large files are not saved to disk. Function duration is configured for 60 seconds; the individual district requests retain their 15-second timeouts.

## Verify after deployment

- Anonymous visits show sign-in, and signed-out API requests return 401.
- Sign in with an actual district account; open grades, schedule, and documents.
- Refresh the browser and verify the session survives. Download a small document.
- Sign out and verify the workspace and server session are cleared.
- Preview and Production use separate storage namespaces.

Automated tests cover the local/shared store behavior, revocation, fail-closed configuration, and download authorization. Actual Vercel/Upstash provisioning and a live district login require deployment verification.

The Vercel output was generated locally on Windows using a test-only directory-junction workaround for Windows symlink permissions. Vercel's Linux build environment uses the unmodified official adapter. This packaging check does not replace a real hosted deployment check.

References: [SvelteKit Vercel adapter](https://svelte.dev/docs/kit/adapter-vercel), [Upstash REST API](https://upstash.com/docs/redis/features/restapi), [Vercel function limits](https://vercel.com/docs/functions/limitations).
