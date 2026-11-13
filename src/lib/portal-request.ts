export class RequestFailure extends Error {
  status: number;
  constructor(message: string, status = 0) {
    super(message);
    this.status = status;
  }
}
export async function requestPortal(
  body: Record<string, unknown>,
  transport: typeof fetch = fetch,
): Promise<Record<string, unknown>> {
  let response: Response;
  try {
    response = await transport('/api/portal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      cache: 'no-store',
    });
  } catch {
    throw new RequestFailure(
      'Schoolity could not connect. Check your connection and try again. Your current workspace has been kept.',
    );
  }
  if (response.status === 401)
    throw new RequestFailure(
      body.action === 'login'
        ? 'Your district did not accept these credentials. Check your username and password, then try again.'
        : 'Your session has ended. Sign in again to continue.',
      401,
    );
  if (response.status === 429)
    throw new RequestFailure(
      'Too many sign-in attempts. Wait ten minutes before trying again.',
      429,
    );
  if (response.status >= 500)
    throw new RequestFailure(
      'Your school’s connection is temporarily unavailable. Try again in a moment; your current workspace has been kept.',
      response.status,
    );
  let answer: Record<string, unknown>;
  try {
    const raw: unknown = await response.json();
    answer =
      raw !== null && typeof raw === 'object' && !Array.isArray(raw)
        ? (raw as Record<string, unknown>)
        : {};
  } catch {
    throw new RequestFailure(
      'The connection returned an unreadable response. Try again in a moment.',
      response.status,
    );
  }
  if (!response.ok) {
    const provided = typeof answer.error === 'string' ? answer.error : '';
    throw new RequestFailure(
      provided ||
        'This request could not be completed. Check the information and try again.',
      response.status,
    );
  }
  return answer;
}
