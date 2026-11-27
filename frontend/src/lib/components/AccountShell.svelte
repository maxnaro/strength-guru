<script lang="ts">
  import { onMount } from "svelte";
  import { afterNavigate } from "$app/navigation";
  import TrainingApp from "./TrainingApp.svelte";
  import Sheet from "./Sheet.svelte";
  import { Training, exportLegacyReplica } from "$lib/data";
  import { adoptLegacyDrafts, legacyDrafts } from "$lib/domain/drafts";
  import {
    accountApi,
    AccountConnection,
    cachedSession,
    rememberSession,
    sessionKey,
    validUntil,
    type AccountSession,
    type CachedSession,
  } from "$lib/data/account";
  import { download } from "$lib/domain/training";

  let checking = true;
  let busy = false;
  let error = "";
  let routeUrl = new URL("http://localhost/");
  afterNavigate(({ to }) => {
    routeUrl = to?.url ?? new URL(location.href);
  });
  $: fragment = routeUrl.pathname === "/invite" ? routeUrl.hash.slice(1) : "";
  $: token = fragment.startsWith("token=") ? new URLSearchParams(fragment).get("token") || "" : fragment;
  let connection: AccountConnection | undefined;
  let training: Training | undefined;
  let migration: Training | undefined;
  let cache: CachedSession | undefined;
  let version = 0;
  let refreshInProgress = false;
  let signingOut = false;
  const logoutKey = "strength-guru-logout-pending";
  let logoutFailed = false;
  let logoutAccount: string | undefined;
  let expiryTimer: ReturnType<typeof setTimeout>;
  let bus: BroadcastChannel | undefined;
  let accountOpen = false;
  let invites: { id: string; createdAt: string; expiresAt: string; status: string }[] = [];
  let inviteUrl = "";
  let legacyAvailable = false;

  function closeAccount() {
    clearTimeout(expiryTimer);
    connection?.close();
    training?.close();
    migration?.close();
    connection = undefined;
    training = undefined;
    migration = undefined;
    cache = undefined;
    accountOpen = false;
    if (!signingOut) busy = false;
    invites = [];
    inviteUrl = "";
    legacyAvailable = false;
  }

  function invalidate(accountId = connection?.id ?? cachedSession()?.session.accountId) {
    const latest = cachedSession();
    version++;
    closeAccount();
    if (!latest || latest.session.accountId === accountId) {
      rememberSession();
      bus?.postMessage({ signedOut: accountId });
    }
    checking = false;
  }

  function updateExpiry(value: CachedSession) {
    cache = value;
    connection?.update(value);
    clearTimeout(expiryTimer);
    expiryTimer = setTimeout(() => {
      closeAccount();
      void refresh();
    }, Math.max(0, validUntil(value) - Date.now()));
  }

  async function useSession(value: CachedSession, online: boolean, check: number) {
    if (check !== version || validUntil(value) <= Date.now()) return;
    if (connection?.id === value.session.accountId && (training || migration)) {
      updateExpiry(value);
      return;
    }
    closeAccount();
    const next = new AccountConnection(value.session.accountId, value, () => invalidate(next.id));
    const replica = new Training(next);
    connection = next;
    updateExpiry(value);
    let legacyStatus: "none" | "adoptable" | "export" = "none";
    if (value.session.legacyOwner) {
      try {
        if (online) legacyStatus = await replica.legacyStatus();
        else if ((await exportLegacyReplica()).epoch) legacyStatus = "export";
      } catch {
        if ((await exportLegacyReplica().catch(() => undefined))?.epoch) legacyStatus = "export";
      }
    }
    if (check !== version || next.signal.aborted) {
      replica.close();
      return;
    }
    legacyAvailable = legacyStatus !== "none";
    if (legacyStatus === "adoptable") migration = replica;
    else training = replica;
  }

  async function finishMigration(adopt: boolean) {
    const current = connection;
    const replica = migration;
    if (!current || !replica) return;
    busy = true;
    error = "";
    try {
      if (adopt) {
        if (!(await replica.migrateLegacy(() => adoptLegacyDrafts(current.id)))) {
          error = "This account already has a local snapshot or the server data changed. You can export your previous app data.";
          return;
        }
        legacyAvailable = false;
      }
      current.assertActive();
      migration = undefined;
      training = replica;
    } catch (e) {
      if (!current.signal.aborted) error = e instanceof Error ? e.message : String(e);
    } finally {
      if (!current.signal.aborted) busy = false;
    }
  }

  async function refresh() {
    if (refreshInProgress || signingOut || pendingLogout()) return;
    refreshInProgress = true;
    const check = version;
    try {
      const response = await fetch("/api/v1/auth/session", {
        cache: "no-store",
        signal: AbortSignal.timeout(5000),
      });
      if (check !== version) return;
      if (response.status === 401) {
        if (connection || cachedSession()) invalidate();
        return;
      }
      if (!response.ok) {
        if (!connection) error = "Could not verify your session.";
        return;
      }
      const session = await response.json() as AccountSession;
      if (check !== version) return;
      const value = { session, verifiedAt: Date.now() };
      rememberSession(value);
      await useSession(value, true, check);
    } catch (failure) {
      if (check !== version) return;
      if (failure instanceof SyntaxError) {
        if (!connection) error = "Could not verify your session.";
        return;
      }
      const value = cachedSession();
      if (value) await useSession(value, false, check);
    } finally {
      refreshInProgress = false;
      if (check === version) checking = false;
      else if (checking) void refresh();
    }
  }

  function pendingLogout() {
    try {
      return localStorage.getItem(logoutKey) ?? undefined;
    } catch {
      return logoutAccount;
    }
  }

  function setPendingLogout(id?: string) {
    logoutAccount = id;
    try {
      if (id) localStorage.setItem(logoutKey, id);
      else localStorage.removeItem(logoutKey);
    } catch {
      // Keep the pending logout in memory for this tab.
    }
  }

  function crossTabChange(signedOut = false) {
    logoutAccount = pendingLogout();
    logoutFailed = !!logoutAccount;
    const value = cachedSession();
    if (!signedOut && !logoutFailed && value?.session.accountId === connection?.id) return;
    version++;
    closeAccount();
    checking = !signedOut && !logoutFailed && !!value;
    if (checking) void refresh();
  }

  onMount(() => {
    routeUrl = new URL(location.href);
    const authError = routeUrl.searchParams.get("authError");
    if (authError === "invitation_required") error = "An invitation is required to create an account.";
    else if (authError === "invalid_invitation") error = "This invitation has expired or has already been used.";
    else if (authError) error = "Sign-in failed. Please try again.";
    if (typeof BroadcastChannel !== "undefined") {
      bus = new BroadcastChannel("strength-guru-account");
      bus.onmessage = ({ data }) => {
        if (data?.signedOut && data.signedOut === connection?.id) crossTabChange(true);
      };
    }
    const storageChanged = (event: StorageEvent) => {
      if ([sessionKey, logoutKey, null].includes(event.key)) crossTabChange();
    };
    const whenVisible = () => {
      if (document.visibilityState === "visible") void refresh();
    };
    const timer = setInterval(whenVisible, 15000);
    window.addEventListener("storage", storageChanged);
    window.addEventListener("online", refresh);
    document.addEventListener("visibilitychange", whenVisible);
    logoutAccount = pendingLogout();
    if (logoutAccount) {
      checking = false;
      logoutFailed = true;
      void signOut();
    } else void refresh();
    return () => {
      version++;
      clearInterval(timer);
      closeAccount();
      bus?.close();
      window.removeEventListener("storage", storageChanged);
      window.removeEventListener("online", refresh);
      document.removeEventListener("visibilitychange", whenVisible);
    };
  });

  async function signIn() {
    busy = true;
    error = "";
    try {
      const returnTo = routeUrl.pathname === "/invite" ? "/" : routeUrl.pathname +
        (routeUrl.searchParams.has("authError") ? "" : routeUrl.search);
      const response = await fetch("/api/v1/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...(token ? { invite: token } : {}), returnTo }),
        signal: AbortSignal.timeout(10000),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.message || "Could not start sign-in.");
      location.assign(result.authorizationUrl);
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
      busy = false;
    }
  }

  async function signOut() {
    const accountId = connection?.id ?? logoutAccount;
    if (!accountId) return;
    setPendingLogout(accountId);
    signingOut = true;
    busy = true;
    error = "";
    invalidate(accountId);
    try {
      const response = await fetch("/api/v1/auth/logout", {
        method: "POST",
        headers: { "content-type": "application/json", "X-Strength-Guru-Account": accountId },
        body: "{}",
        cache: "no-store",
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok && response.status !== 401 &&
          !(response.status === 409 && (await response.json().catch(() => null))?.code === "account_changed"))
        throw new Error("Could not sign out on the server.");
      logoutFailed = false;
      setPendingLogout();
    } catch {
      logoutFailed = true;
      error = "Could not sign out on the server. Reconnect and retry.";
    } finally {
      busy = false;
      signingOut = false;
    }
  }

  async function inviteAction(path = "auth/invites", method = "GET") {
    const current = connection;
    if (!current || !cache?.session.owner) return;
    busy = true;
    error = "";
    try {
      if (method !== "GET") {
        const result = await accountApi(current, path, method, {});
        if (method === "POST") inviteUrl = result.url;
      }
      invites = (await accountApi(current, "auth/invites")).invites;
    } catch (e) {
      if (!current.signal.aborted) error = e instanceof Error ? e.message : String(e);
    } finally {
      if (!current.signal.aborted) busy = false;
    }
  }

  async function exportLegacy() {
    const current = connection;
    if (!cache?.session.legacyOwner || !current) return;
    try {
      const [replica, drafts] = await Promise.all([exportLegacyReplica(), legacyDrafts()]);
      current.assertActive();
      download(JSON.stringify({ replica, drafts }, null, 2), "strength-guru-legacy.json");
    } catch (e) {
      if (!current.signal.aborted) error = e instanceof Error ? e.message : String(e);
    }
  }

  function openAccount() {
    accountOpen = true;
    error = "";
    void inviteAction();
  }
</script>

<svelte:head><title>StrengthGuru</title></svelte:head>

{#if connection && training && routeUrl.pathname === "/invite"}
  <main class="account-entry" id="main">
    <h1>StrengthGuru</h1>
    <p>You are signed in.</p>
    <a href="/log">Open training</a>
    <button disabled={busy} on:click={signOut}>Sign out</button>
  </main>
{:else if migration && connection}
  <main class="account-entry" id="main">
    <h1>Import previous app data</h1>
    <p>Training edits and drafts saved in this browser can be added to your account.</p>
    <button class="solid" disabled={busy} on:click={() => finishMigration(true)}>Import previous app data</button>
    <button disabled={busy} on:click={exportLegacy}>Export previous app data</button>
    <button disabled={busy} on:click={() => finishMigration(false)}>Continue without importing</button>
    <button disabled={busy} on:click={signOut}>Sign out</button>
    {#if error}<p class="warning" role="alert">{error}</p>{/if}
  </main>
{:else if connection && training}
  {#key connection}
    <TrainingApp account={connection} {training} {openAccount} />
  {/key}
{:else}
  <main class="account-entry" id="main">
    <h1>StrengthGuru</h1>
    {#if checking}
      <p role="status">Checking your session…</p>
    {:else if logoutFailed}
      <button class="solid" disabled={busy} on:click={signOut}>Retry sign-out</button>
    {:else if routeUrl.pathname === "/invite" && !token}
      <p>This invitation link is incomplete.</p>
      <a href="/">Return to sign in</a>
    {:else}
      {#if token}<p>Sign in to accept your invitation.</p>{/if}
      <button class="solid" disabled={busy} on:click={signIn}>Sign in</button>
    {/if}
    {#if error}<p class="warning" role="alert">{error}</p>{/if}
  </main>
{/if}

{#if accountOpen && cache}
  <Sheet title="Account" close={() => (accountOpen = false)}>
    <button class="full" disabled={busy} on:click={signOut}>Sign out</button>
    {#if cache.session.owner}
      <h3>Invitations</h3>
      <button class="full" disabled={busy} on:click={() => inviteAction("auth/invites", "POST")}>Create invitation</button>
      {#if inviteUrl}
        <label>Invitation link <input readonly value={inviteUrl} /></label>
        <button class="full" on:click={() => navigator.clipboard.writeText(inviteUrl).catch(() => (error = "Could not copy the link."))}>Copy invitation link</button>
      {/if}
      {#each invites as invite (invite.id)}
        <div class="row">
          <span class="grow">{invite.status} · {new Date(invite.expiresAt).toLocaleDateString()}</span>
          {#if invite.status === "active"}
            <button disabled={busy} on:click={() => inviteAction(`auth/invites/${invite.id}`, "DELETE")}>Revoke invitation</button>
          {/if}
        </div>
      {/each}
    {/if}
    {#if legacyAvailable}
      <p>Training and drafts from the previous app are available to export.</p>
      <button class="full" on:click={exportLegacy}>Export previous app data</button>
    {/if}
    {#if error}<p class="warning" role="alert">{error}</p>{/if}
  </Sheet>
{/if}

<style>
  .account-entry {
    width: min(100% - 2rem, 32rem);
    margin: 12vh auto 0;
  }
  input[readonly] {
    width: 100%;
  }
</style>
