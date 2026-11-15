import { readJsonRequest } from "$lib/server/json-request";
import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { PortalError } from "$lib/server/portal";
import { browserAuth } from "$lib/server/browser-auth";
import {
  downloadDocument,
  downloadMailAttachment,
} from "$lib/server/documents";

export const POST: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
  const headers = {
    "Cache-Control": "no-store",
    Pragma: "no-cache",
    "X-Content-Type-Options": "nosniff",
  };
  try {
    const input = await readJsonRequest(request, url, 1024);
    if (
      input.kind !== undefined &&
      input.kind !== "document" &&
      input.kind !== "mail"
    )
      throw new PortalError("Unsupported download type.", 400);
    const file = await browserAuth.withSession(
      { cookies, url, getClientAddress },
      (session) =>
        input.kind === "mail"
          ? downloadMailAttachment(session, input.messageId, input.id)
          : downloadDocument(session, input.id),
    );
    const ascii = file.filename.replace(/[^\x20-\x7e]/g, "_");
    const encoded = encodeURIComponent(file.filename).replace(
      /['()*]/g,
      (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase(),
    );
    return new Response(new Uint8Array(file.bytes), {
      headers: {
        ...headers,
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`,
      },
    });
  } catch (e) {
    return json(
      {
        error:
          e instanceof PortalError ? e.message : "Download failed. Try again.",
      },
      { status: e instanceof PortalError ? e.status : 502, headers },
    );
  }
};
