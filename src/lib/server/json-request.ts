import { object } from "../portal-data.ts";
import { PortalError } from "./portal.ts";

/** Read only same-origin JSON, enforcing the limit on bytes as they arrive. */
export async function readJsonRequest(
  request: Request,
  url: URL,
  limit: number,
) {
  const contentType = request.headers
    .get("content-type")
    ?.split(";")[0]
    .trim()
    .toLowerCase();
  if (
    request.headers.get("origin") !== url.origin ||
    contentType !== "application/json"
  )
    throw new PortalError("A same-origin JSON request is required.", 403);
  if (Number(request.headers.get("content-length")) > limit)
    throw new PortalError("Request too large.", 413);
  const reader = request.body?.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  if (reader) {
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > limit) {
          await reader.cancel();
          throw new PortalError("Request too large.", 413);
        }
        chunks.push(value);
      }
    } finally {
      reader.releaseLock();
    }
  }
  try {
    return object(JSON.parse(Buffer.concat(chunks).toString("utf8")));
  } catch {
    throw new PortalError("Invalid request.", 400);
  }
}
