import type { Cookies } from '@sveltejs/kit';
import { findSession, signIn, endSession, bindRememberedSession, limitLogin, PortalError, type Session } from './portal.ts';
import { rememberedLogins, rememberedLoginKey, REMEMBER_SECONDS } from './remembered-login.ts';
import { sessionCookieOptions } from './session-policy.ts';

export const SESSION_COOKIE = 'schoolity_session';
export const REMEMBER_COOKIE = 'schoolity_remember';
export interface AuthContext {
  cookies: Pick<Cookies, 'get' | 'set' | 'delete'>;
  url: URL;
  getClientAddress: () => string;
}
export interface RememberedStore {
  ensureReady(): void;
  create(credentials: { username: string; password: string }): Promise<string>;
  read(id: string | undefined): Promise<{ username: string; password: string } | undefined>;
  end(id: string | undefined): Promise<void>;
}
export interface BrowserAuthDependencies {
  findSession: typeof findSession;
  signIn: typeof signIn;
  endSession: typeof endSession;
  bindRememberedSession: typeof bindRememberedSession;
  limitLogin: typeof limitLogin;
  remembered: RememberedStore;
}
const defaults: BrowserAuthDependencies = { findSession, signIn, endSession, bindRememberedSession, limitLogin, remembered: rememberedLogins };
export class BrowserAuth {
  private pending = new Map<string, Promise<{ id: string; maxAge: number } | undefined>>();
  private dependencies: BrowserAuthDependencies;
  constructor(dependencies: BrowserAuthDependencies = defaults) { this.dependencies = dependencies; }

  async login(context: AuthContext, username: string, password: string, remember: boolean): Promise<void> {
    const d = this.dependencies;
    if (remember) d.remembered.ensureReady();
    await d.limitLogin(
      'login',
      `${context.getClientAddress()}\n${username.trim().toLowerCase()}`,
    );
    const next = await d.signIn(username.trim(), password);
    let rememberedId: string | undefined;
    try {
      // Clear any previous session before replacing it, but never block a valid
      // sign-in because cleanup of an older session failed.
      await this.logout(context).catch(() => {});
      if (remember) {
        rememberedId = await d.remembered.create({ username: username.trim(), password });
        await d.bindRememberedSession(next.id, rememberedLoginKey(rememberedId));
        context.cookies.set(REMEMBER_COOKIE, rememberedId, sessionCookieOptions(context.url, REMEMBER_SECONDS));
      }
      context.cookies.set(SESSION_COOKIE, next.id, sessionCookieOptions(context.url, next.maxAge));
    } catch (error) {
      await d.endSession(next.id).catch(() => {});
      await d.remembered.end(rememberedId).catch(() => {});
      throw error;
    }
  }
  async logout(context: AuthContext): Promise<void> {
    const d = this.dependencies;
    let failed = false;
    // Revoke the parent first so any renewal already in flight cannot restore the session.
    try { await d.remembered.end(context.cookies.get(REMEMBER_COOKIE)); }
    catch { failed = true; }
    try { await d.endSession(context.cookies.get(SESSION_COOKIE)); }
    catch { failed = true; }
    context.cookies.delete(REMEMBER_COOKIE, { path: '/' });
    context.cookies.delete(SESSION_COOKIE, { path: '/' });
    if (failed)
      throw new PortalError('Signed out on this browser, but server cleanup failed. Try again.', 503);
  }
  // Rendering reads the current session only. Renewal contacts the district,
  // so it belongs to an explicit request the client can show progress for.
  async existing(
    context: Pick<AuthContext, 'cookies'>,
  ): Promise<Session | undefined> {
    return await this.dependencies.findSession(
      context.cookies.get(SESSION_COOKIE),
    );
  }
  private async renew(id: string): Promise<{ id: string; maxAge: number } | undefined> {
    const d = this.dependencies;
    const credentials = await d.remembered.read(id);
    if (!credentials) return undefined;
    await d.limitLogin('renew', id);
    let next;
    try { next = await d.signIn(credentials.username, credentials.password); }
    catch (error) {
      if (error instanceof PortalError && error.status === 401) { await d.remembered.end(id); return undefined; }
      throw error;
    }
    await d.bindRememberedSession(next.id, rememberedLoginKey(id));
    if (!await d.findSession(next.id)) { await d.endSession(next.id); return undefined; }
    return next;
  }
  async restore(context: AuthContext, force = false): Promise<Session | undefined> {
    const d = this.dependencies, oldId = context.cookies.get(SESSION_COOKIE);
    if (!force) { const session = await d.findSession(oldId); if (session) return session; }
    const id = context.cookies.get(REMEMBER_COOKIE);
    if (!id) return undefined;
    let pending = this.pending.get(id);
    if (!pending) {
      pending = this.renew(id);
      this.pending.set(id, pending);
    }
    let next;
    try { next = await pending; }
    finally { if (this.pending.get(id) === pending) this.pending.delete(id); }
    if (!next) {
      context.cookies.delete(REMEMBER_COOKIE, { path: '/' });
      context.cookies.delete(SESSION_COOKIE, { path: '/' });
      if (oldId) await d.endSession(oldId);
      return undefined;
    }
    if (oldId && oldId !== next.id) await d.endSession(oldId);
    context.cookies.set(SESSION_COOKIE, next.id, sessionCookieOptions(context.url, next.maxAge));
    return await d.findSession(next.id);
  }
  async withSession<T>(context: AuthContext, operation: (session: Session) => Promise<T>): Promise<T> {
    const session = await this.restore(context);
    if (!session) throw new PortalError('Your session has ended. Sign in again.', 401);
    try { return await operation(session); }
    catch (error) {
      if (!(error instanceof PortalError) || error.status !== 401 || !context.cookies.get(REMEMBER_COOKIE)) throw error;
      const renewed = await this.restore(context, true);
      if (!renewed) throw new PortalError('Your saved sign-in has ended. Enter your username and password again.', 401);
      return await operation(renewed);
    }
  }
}
export const browserAuth = new BrowserAuth();
