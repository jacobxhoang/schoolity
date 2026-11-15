export class RequestFailure extends Error {
  status: number;
  constructor(message: string, status = 0) {
    super(message);
    this.status = status;
  }
}
// A district web-page session can expire while the mobile API still works.
// Confirm the main session before allowing a section failure to clear the workspace.
export async function requestWorkspacePortal(
  body: Record<string, unknown>,
  transport: typeof fetch = fetch,
): Promise<Record<string, unknown>> {
  try {
    return await requestPortal(body, transport);
  } catch (error) {
    if (
      !(error instanceof RequestFailure) ||
      error.status !== 401 ||
      body.action !== "read" ||
      body.resource === "grades"
    )
      throw error;
    await requestPortal({ action: "read", resource: "grades" }, transport);
    throw new RequestFailure(
      "This section’s district session is unavailable. Your workspace has been kept. Retry, or sign out and sign in again to reconnect this section.",
      409,
    );
  }
}
export async function requestPortal(
  body: Record<string, unknown>,
  transport: typeof fetch = fetch,
): Promise<Record<string, unknown>> {
  // Only repeat reads: sign-in, sign-out and session renewal must run once.
  for (let attempt = 0; ; attempt++) {
    try {
      return await requestOnce(body, transport);
    } catch (error) {
      if (
        body.action !== "read" ||
        attempt >= 2 ||
        !(error instanceof RequestFailure) ||
        ![0, 502, 503, 504].includes(error.status)
      )
        throw error;
      await new Promise((resolve) =>
        setTimeout(resolve, attempt === 0 ? 400 : 1000),
      );
    }
  }
}

async function requestOnce(
  body: Record<string, unknown>,
  transport: typeof fetch,
): Promise<Record<string, unknown>> {
  let response: Response;
  try {
    response = await transport("/api/portal", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      cache: "no-store",
    });
  } catch {
    throw new RequestFailure(
      "Schoolity could not connect. Check your connection and try again. Your current workspace has been kept.",
    );
  }
  if (response.status === 401)
    throw new RequestFailure(
      body.action === "login"
        ? "Your district did not accept these credentials. Check your username and password, then try again."
        : "Your session has ended. Sign in again to continue.",
      401,
    );
  if (response.status === 429)
    throw new RequestFailure(
      "Too many sign-in attempts. Wait ten minutes before trying again.",
      429,
    );
  let answer: Record<string, unknown>;
  try {
    const raw: unknown = await response.json();
    answer =
      raw !== null && typeof raw === "object" && !Array.isArray(raw)
        ? (raw as Record<string, unknown>)
        : {};
  } catch {
    throw new RequestFailure(
      response.status >= 500
        ? "Your school’s connection is temporarily unavailable. Try again in a moment; your current workspace has been kept."
        : "The connection returned an unreadable response. Try again in a moment.",
      response.status,
    );
  }
  if (!response.ok) {
    const provided = typeof answer.error === "string" ? answer.error : "";
    throw new RequestFailure(
      provided ||
        (response.status >= 500
          ? "Your school’s connection is temporarily unavailable. Try again in a moment; your current workspace has been kept."
          : "This request could not be completed. Check the information and try again."),
      response.status,
    );
  }
  return answer;
}
