export type AccountSession = {
  accountId: string;
  owner: boolean;
  legacyOwner: boolean;
  expiresAt: string;
};

export const sessionKey = "strength-guru-account-session";
const offlineWindow = 7 * 24 * 60 * 60 * 1000;

export type CachedSession = {
  session: AccountSession;
  verifiedAt: number;
};

export function validUntil({ session, verifiedAt }: CachedSession) {
  return Math.min(Date.parse(session.expiresAt), verifiedAt + offlineWindow);
}

export function cachedSession(): CachedSession | undefined {
  try {
    const cache = JSON.parse(localStorage.getItem(sessionKey) ?? "null") as CachedSession | null;
    if (cache?.session?.accountId && validUntil(cache) > Date.now()) return cache;
  } catch {
    // The app can still use an online session when local storage is unavailable.
  }
}

export function rememberSession(cache?: CachedSession) {
  try {
    if (cache) localStorage.setItem(sessionKey, JSON.stringify(cache));
    else localStorage.removeItem(sessionKey);
  } catch {
    // Cross-tab notification also uses BroadcastChannel.
  }
}

export class AccountConnection {
  private controller = new AbortController();
  readonly signal = this.controller.signal;
  private deadline: number;

  constructor(readonly id: string, cache: CachedSession, private invalidated: () => void) {
    this.deadline = validUntil(cache);
  }

  update(cache: CachedSession) {
    this.deadline = validUntil(cache);
  }

  close() {
    this.controller.abort();
  }

  assertActive() {
    if (!this.signal.aborted && Date.now() >= this.deadline) this.invalidated();
    this.signal.throwIfAborted();
  }

  fetch = async (url: string, init: RequestInit = {}) => {
    this.assertActive();
    const headers = new Headers(init.headers);
    headers.set("X-Strength-Guru-Account", this.id);
    const response = await fetch(url, {
      ...init,
      headers,
      cache: "no-store",
      signal: init.signal ? AbortSignal.any([this.signal, init.signal]) : this.signal,
    });
    if (response.status === 401 ||
        (response.status === 409 && (await response.clone().json().catch(() => null))?.code === "account_changed"))
      this.invalidated();
    this.assertActive();
    return response;
  };
}

export async function accountApi(account: AccountConnection, path: string, method = "GET", body?: any) {
  const r = await account.fetch(`/api/v1/${path}`, {
    method,
    signal: AbortSignal.timeout(20000),
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await r.json();
  account.assertActive();
  if (!r.ok)
    throw Error(
      data.message ||
        data.error?.message ||
        data.error ||
        `Request failed (${r.status})`,
    );
  return data;
}
