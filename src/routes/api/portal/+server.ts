import { readJsonRequest } from "$lib/server/json-request";
import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { PortalError, read, readHistorySubject } from "$lib/server/portal";
import { nativeData, schedule } from "$lib/portal-data";
import { DISTRICT_URL } from "$lib/config";
import { browserAuth, SESSION_COOKIE } from "$lib/server/browser-auth";
import { gradeCacheIdentity } from "$lib/server/grade-cache-identity";
import { readRecords } from "$lib/records";
export const POST: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
  const context = { cookies, url, getClientAddress };
  const headers = { "Cache-Control": "no-store", Pragma: "no-cache" };
  try {
    const input = await readJsonRequest(request, url, 8192);
    if (input.action === "logout") {
      await browserAuth.logout(context);
      return json({ ok: true }, { headers });
    }
    if (input.action === "login") {
      if (
        typeof input.username !== "string" ||
        typeof input.password !== "string" ||
        !input.username.trim() ||
        !input.password
      )
        throw new PortalError("Enter your username and password.", 400);
      if (input.remember !== undefined && typeof input.remember !== "boolean")
        throw new PortalError("Choose whether to stay signed in.", 400);
      if (
        input.district !== undefined &&
        input.district !== DISTRICT_URL &&
        input.district !== "synergyportal.anoka.k12.mn.us"
      )
        throw new PortalError(
          "This Schoolity instance only connects to the configured Anoka district.",
          400,
        );
      await browserAuth.login(
        context,
        input.username,
        input.password,
        input.remember === true,
      );
      return json(
        {
          ok: true,
          cacheIdentity: gradeCacheIdentity(cookies.get(SESSION_COOKIE)),
        },
        { headers },
      );
    }
    if (input.action === "session") {
      const session = await browserAuth.restore(context);
      return json(
        {
          connected: !!session,
          cacheIdentity: session
            ? gradeCacheIdentity(cookies.get(SESSION_COOKIE))
            : null,
        },
        { headers },
      );
    }
    if (typeof input.resource !== "string")
      throw new PortalError("Select a resource.", 400);
    const resource = input.resource;
    // Keep the existing native schedule shape for installed clients. The
    // term-aware shape is opt-in under a new resource name.
    const source = resource === "schedule-terms" ? "schedule" : resource;
    const data = await browserAuth.withSession(context, (session) =>
      resource === "history-subject"
        ? readHistorySubject(session, input.subject)
        : read(session, source, input.term),
    );
    const normalized =
      input.normalized === true && resource !== "history-subject";
    const payload = !normalized
      ? data
      : resource === "schedule-terms"
        ? schedule(data)
        : ["student", "history", "attendance"].includes(resource)
          ? readRecords(resource, data)
          : nativeData(data, resource);
    return json(
      {
        data: payload,
        cacheIdentity: gradeCacheIdentity(cookies.get(SESSION_COOKIE)),
      },
      { headers },
    );
  } catch (error) {
    return json(
      {
        error:
          error instanceof PortalError
            ? error.message
            : "Could not reach your district. Try again.",
      },
      { status: error instanceof PortalError ? error.status : 502, headers },
    );
  }
};
