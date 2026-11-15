import type { Handle } from "@sveltejs/kit";

// Sent with every response, including JSON endpoints and file downloads, so a
// page cannot be framed, sniffed as another type, or leak a referrer.
const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "same-origin",
  "Permissions-Policy":
    "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Resource-Policy": "same-origin",
};

export const handle: Handle = async ({ event, resolve }) => {
  const response = await resolve(event);
  for (const [name, value] of Object.entries(SECURITY_HEADERS))
    if (!response.headers.has(name)) response.headers.set(name, value);
  // Only meaningful over HTTPS; local development runs on plain HTTP.
  if (
    event.url.protocol === "https:" &&
    !response.headers.has("Strict-Transport-Security")
  )
    response.headers.set(
      "Strict-Transport-Security",
      "max-age=63072000; includeSubDomains",
    );
  return response;
};
