// Keep the district's validity window, bounded to 30 days. Never extend its token.
export function sessionLifetime(expiresIn: unknown): number {
  const seconds =
    typeof expiresIn === 'number' || typeof expiresIn === 'string'
      ? Number(expiresIn)
      : NaN;
  return Number.isFinite(seconds) && seconds >= 1
    ? Math.min(Math.floor(seconds), 30 * 86400)
    : 1800;
}
export function sessionCookieOptions(url: URL, maxAge: number) {
  return {
    path: '/',
    httpOnly: true,
    sameSite: 'lax' as const,
    secure: url.protocol === 'https:',
    maxAge,
  };
}
