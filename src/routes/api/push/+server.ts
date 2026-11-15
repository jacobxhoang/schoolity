import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { readJsonRequest } from "$lib/server/json-request";
import { pushService } from "$lib/server/push";
import { PortalError } from "$lib/server/portal";

const headers = { "Cache-Control": "no-store", Pragma: "no-cache" };
export const GET: RequestHandler = async () => {
  try {
    pushService.ensureReady();
    return json({ available: true }, { headers });
  } catch {
    return json({ available: false }, { headers });
  }
};
export const POST: RequestHandler = async ({
  request,
  url,
  getClientAddress,
}) => {
  try {
    const input = await readJsonRequest(request, url, 8192);
    const secret =
      request.headers.get("authorization")?.replace(/^Bearer /, "") ?? "";
    if (input.action === "register")
      return json(
        await pushService.register(input, secret, getClientAddress()),
        { headers },
      );
    if (input.action === "status")
      return json(await pushService.status(input.id, secret), { headers });
    if (input.action === "delete") {
      await pushService.remove(input.id, secret);
      return json({ ok: true }, { headers });
    }
    throw new PortalError("Choose a notification action.", 400);
  } catch (error) {
    return json(
      {
        error:
          error instanceof PortalError
            ? error.message
            : "The notification service is unavailable. Try again.",
      },
      { status: error instanceof PortalError ? error.status : 503, headers },
    );
  }
};
