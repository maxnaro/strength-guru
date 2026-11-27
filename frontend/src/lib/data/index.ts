import { v5 as uuidv5 } from "uuid";

type Row = Record<string, any>;
type Tables = Record<string, Row[]>;
type CommandBody = {
  operationId: string;
  epoch: string;
  type: string;
  payload: Row;
  expectedRevision: number;
  expectedProgramRevision?: number;
};
type Queued = {
  id: string;
  resource: string;
  body: CommandBody;
  state: "pending" | "conflict" | "accepted";
  sent: boolean;
  guardedProgramEdit?: boolean;
  error?: string;
  code?: string;
  response?: { result: any; resource: string; revision: number };
};
type Replica = {
  epoch?: string;
  cursor?: number;
  tables: Tables;
  revisions: Record<string, number>;
  outbox: Queued[];
  restorePending?: string;
  results?: Row;
  resultSignatures?: Record<string, string>;
  resultEpochs?: Record<string, string>;
  resultBodies?: Record<string, CommandBody>;
  tableGeneration?: number;
};
export type Conflict = Queued & {
  localValue: Row | null;
  serverValue: Row | null;
  result?: any;
};
export type TrainingState = {
  tables: Tables;
  ready: boolean;
  connected: boolean;
  pending: number;
  conflicts: Conflict[];
  error?: string;
  epoch?: string;
  programRevision: number;
};
type ProgramVersion = { epoch: string; programRevision: number };

const keys: Record<string, string[]> = {
  mesocycles: ["id"],
  exercises: ["id"],
  exercise_slots: ["id"],
  week_targets: ["mesocycle_id", "week_idx", "slot_id"],
  program_days: ["mesocycle_id", "day_idx"],
  day_overrides: ["mesocycle_id", "week_idx", "day_idx"],
  session_logs: ["id"],
  set_entries: ["id"],
  settings: ["key"],
};
const logging = new Set([
  "getOrCreateSessionLog",
  "upsertSetEntry",
  "deleteSetEntry",
]);
const namespace = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";
const emptyTables = (): Tables =>
  Object.fromEntries(Object.keys(keys).map((k) => [k, []]));
const emptyReplica = (): Replica => ({
  tables: emptyTables(),
  revisions: {},
  outbox: [],
});
const sameKey = (table: string, a: Row, b: Row) =>
  keys[table].every((k) => a[k] === b[k]);
const clone = <T>(v: T): T => structuredClone(v);
const idForSession = (p: Row) =>
  uuidv5(
    `strength-guru/session/${p.mesoId}/${p.weekIdx}/${p.dayIdx}`,
    namespace,
  );
const idForSet = (p: Row) =>
  uuidv5(
    `strength-guru/set/${p.sessionId}/${p.slotId}/${p.setIndex}`,
    namespace,
  );
const seconds = (date: string) => Math.floor(new Date(date).getTime() / 1000);
const rowSession = (r: Row) => ({
  id: r.id,
  mesocycleId: r.mesocycle_id,
  weekIdx: r.week_idx,
  dayIdx: r.day_idx,
  startedAt:
    r.started_at == null ? null : new Date(r.started_at * 1000).toISOString(),
});
function canonical(value: any): any {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((k) => [k, canonical(value[k])]),
    );
  return value;
}
const actionSignature = (type: string, payload: Row) =>
  JSON.stringify([type, canonical(payload)]);
function resource(type: string, p: Row, tables: Tables): string {
  if (type === "getOrCreateSessionLog")
    return `session:${p.mesoId}:${p.weekIdx}:${p.dayIdx}`;
  if (type === "upsertSetEntry")
    return `set:${p.sessionId}:${p.slotId}:${p.setIndex}`;
  if (type === "deleteSetEntry") {
    const r = tables.set_entries.find((r) => r.id === p.id);
    return r
      ? `set:${r.session_id}:${r.slot_id}:${r.set_index}`
      : p.resource || `deleted:${p.id}`;
  }
  return "program";
}
function overlay(tables: Tables, q: Queued): any {
  const p = q.body.payload;
  if (q.body.type === "getOrCreateSessionLog") {
    let r = tables.session_logs.find(
      (r) =>
        r.mesocycle_id === p.mesoId &&
        r.week_idx === p.weekIdx &&
        r.day_idx === p.dayIdx,
    );
    if (!r) {
      r = {
        id: idForSession(p),
        mesocycle_id: p.mesoId,
        week_idx: p.weekIdx,
        day_idx: p.dayIdx,
        started_at: seconds(p.startedAt),
      };
      tables.session_logs.push(r);
    }
    return rowSession(r);
  }
  if (q.body.type === "upsertSetEntry") {
    const idx = tables.set_entries.findIndex(
      (r) =>
        r.session_id === p.sessionId &&
        r.slot_id === p.slotId &&
        r.set_index === p.setIndex,
    );
    let r: Row;
    if (idx < 0) {
      r = {
        id: idForSet(p),
        session_id: p.sessionId,
        exercise_id: p.exerciseId,
        slot_id: p.slotId,
        set_index: p.setIndex,
      };
      tables.set_entries.push(r);
    } else {
      r = { ...tables.set_entries[idx] };
      tables.set_entries[idx] = r;
    }
    Object.assign(r, {
      weight: p.weight ?? null,
      reps: p.reps ?? null,
      rir: p.rir ?? null,
      done: p.done ? 1 : 0,
      logged_at: p.done ? seconds(p.loggedAt) : null,
    });
  }
  if (q.body.type === "deleteSetEntry")
    tables.set_entries = tables.set_entries.filter((r) => r.id !== p.id);
  return null;
}
function view(r: Replica): Tables {
  const tables = {
    ...r.tables,
    session_logs: [...r.tables.session_logs],
    set_entries: [...r.tables.set_entries],
  };
  for (const q of r.outbox) if (logging.has(q.body.type)) overlay(tables, q);
  return tables;
}
function serverValue(r: Replica, q: Queued): Row | null {
  const p = q.body.payload;
  if (q.body.type === "getOrCreateSessionLog")
    return (
      r.tables.session_logs.find(
        (x) =>
          x.mesocycle_id === p.mesoId &&
          x.week_idx === p.weekIdx &&
          x.day_idx === p.dayIdx,
      ) || null
    );
  if (q.body.type === "upsertSetEntry")
    return (
      r.tables.set_entries.find(
        (x) =>
          x.session_id === p.sessionId &&
          x.slot_id === p.slotId &&
          x.set_index === p.setIndex,
      ) || null
    );
  if (q.body.type === "deleteSetEntry")
    return (
      r.tables.set_entries.find(
        (x) =>
          x.id === p.id ||
          (p.resource &&
            `set:${x.session_id}:${x.slot_id}:${x.set_index}` === p.resource),
      ) || null
    );
  return null;
}
function receipts(r: Replica): Conflict[] {
  return Object.keys(r.results || {}).map((id) => {
    const epoch = r.resultEpochs?.[id];
    const body = r.resultBodies?.[id] || {
      operationId: id,
      epoch: epoch || "",
      type: "unknown",
      payload: {},
      expectedRevision: 0,
    };
    const stale = !epoch || epoch !== r.epoch;
    return {
      id,
      resource: "program",
      body,
      state: "conflict",
      sent: true,
      code: stale ? "dataset_changed" : "result_unconfirmed",
      error: stale
        ? "This result belongs to a different server dataset. Export or discard it before repeating the action."
        : "A completed change has not been confirmed. Retry the original action to recover its result, or export and discard it.",
      localValue: body.payload,
      serverValue: null,
      result: r.results![id],
    };
  });
}
function applyPage(r: Replica, page: Row) {
  if (page.snapshot) {
    r.tables = emptyTables();
    for (const table of Object.keys(keys))
      r.tables[table] = page.snapshot[table] || [];
    r.revisions = Object.fromEntries(
      (page.revisions || []).map((x: Row) => [x.resource, x.revision]),
    );
  }
  for (const c of page.changes || []) {
    const row = JSON.parse(c.data);
    if (c.table === "sg_revisions") {
      if (c.deleted) delete r.revisions[row.resource];
      else r.revisions[row.resource] = row.revision;
      continue;
    }
    if (!keys[c.table]) throw new Error(`Unknown sync table ${c.table}`);
    const rows = r.tables[c.table];
    const idx = rows.findIndex((x) => sameKey(c.table, x, row));
    if (c.deleted) {
      if (idx >= 0) rows.splice(idx, 1);
    } else if (idx >= 0) rows[idx] = row;
    else rows.push(row);
  }
  r.epoch = page.epoch;
  r.cursor = page.cursor;
}
class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number,
  ) {
    super(message);
  }
}
const changedProgramMessage =
  "The program changed. Close and reopen the editor to review the latest values.";
async function request(path: string, method = "GET", body?: any): Promise<any> {
  const response = await fetch(`/api/v1/${path}`, {
    method,
    headers:
      body === undefined ? undefined : { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(20000),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok)
    throw new ApiError(
      json.code || "server_error",
      json.message || `Request failed (${response.status})`,
      response.status,
    );
  return json;
}
let dbPromise: Promise<IDBDatabase> | undefined;
let tableCache: { generation: number; tables: Tables } | undefined;
function database(): Promise<IDBDatabase> {
  return (dbPromise ??= new Promise<IDBDatabase>((resolve, reject) => {
    const req = indexedDB.open("strength-guru-replica", 2);
    req.onupgradeneeded = (event) => {
      if (event.oldVersion === 0) req.result.createObjectStore("replica");
      const canonicalStore = req.result.createObjectStore("canonical");
      if (event.oldVersion > 0) {
        const metadata = req.transaction!.objectStore("replica");
        const previous = metadata.get("current");
        previous.onsuccess = () => {
          if (!previous.result) return;
          const { tables, ...rest } = previous.result;
          canonicalStore.put(tables || emptyTables(), "current");
          metadata.put({ ...rest, tableGeneration: 1 }, "current");
        };
      }
    };
    req.onsuccess = () => {
      req.result.onversionchange = () => {
        req.result.close();
        dbPromise = undefined;
        tableCache = undefined;
      };
      resolve(req.result);
    };
    req.onerror = () => reject(req.error);
    req.onblocked = () =>
      reject(new Error("Close other tabs to open local storage."));
  }).catch((e) => {
    dbPromise = undefined;
    throw e;
  }));
}
async function read(): Promise<Replica> {
  const db = await database();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(["replica", "canonical"], "readonly");
    const req = tx.objectStore("replica").get("current");
    req.onsuccess = () => {
      if (!req.result) {
        resolve(emptyReplica());
        return;
      }
      const meta = req.result;
      if (tableCache && tableCache.generation === meta.tableGeneration) {
        resolve({ ...meta, tables: tableCache.tables });
        return;
      }
      const canonical = tx.objectStore("canonical").get("current");
      canonical.onsuccess = () => {
        if (!canonical.result) {
          reject(new Error("The local training snapshot is missing."));
          return;
        }
        tableCache = {
          generation: meta.tableGeneration,
          tables: canonical.result,
        };
        resolve({ ...meta, tables: canonical.result });
      };
      canonical.onerror = () => reject(canonical.error);
    };
    req.onerror = () => reject(req.error);
    tx.onabort = () =>
      reject(tx.error || new Error("Unable to read workout data"));
  });
}
async function save(r: Replica): Promise<void> {
  const db = await database();
  return new Promise((resolve, reject) => {
    const canonicalChanged =
      !tableCache ||
      r.tableGeneration !== tableCache.generation ||
      r.tables !== tableCache.tables;
    const generation = canonicalChanged
      ? (r.tableGeneration || 0) + 1
      : r.tableGeneration!;
    const { tables, ...meta } = r;
    const tx = db.transaction(["replica", "canonical"], "readwrite");
    if (canonicalChanged) tx.objectStore("canonical").put(tables, "current");
    tx.objectStore("replica").put(
      { ...meta, tableGeneration: generation },
      "current",
    );
    tx.oncomplete = () => {
      r.tableGeneration = generation;
      tableCache = { generation, tables };
      resolve();
    };
    tx.onabort = tx.onerror = () =>
      reject(tx.error || new Error("Unable to save workout data"));
  });
}
class Training {
  private state: TrainingState = {
    tables: emptyTables(),
    ready: false,
    connected: false,
    pending: 0,
    conflicts: [],
    programRevision: 0,
  };
  private listeners = new Set<(s: TrainingState) => void>();
  private channel =
    typeof BroadcastChannel === "undefined"
      ? undefined
      : new BroadcastChannel("strength-guru-replica");
  private init?: Promise<void>;
  private flight?: Promise<void>;
  private again = false;
  private actions = new Map<string, Promise<any>>();
  private timer?: ReturnType<typeof setInterval>;
  constructor() {
    if (this.channel)
      this.channel.onmessage = () => {
        void this.publish();
      };
  }
  subscribe(run: (s: TrainingState) => void): () => void {
    this.listeners.add(run);
    run(this.state);
    return () => this.listeners.delete(run);
  }
  private fail(error: unknown) {
    this.state = {
      ...this.state,
      connected: false,
      error: error instanceof Error ? error.message : String(error),
    };
    for (const f of this.listeners) f(this.state);
  }
  private async publish(error?: string, connected = this.state.connected) {
    const r = await read();
    this.publishReplica(r, error, connected);
  }
  private publishReplica(
    r: Replica,
    error?: string,
    connected = this.state.connected,
  ) {
    error ??= r.restorePending
      ? "A restore is awaiting confirmation. Reconnect before making changes."
      : undefined;
    const savedReceipts = receipts(r);
    const conflicts: Conflict[] = r.outbox
      .filter((q) => q.state === "conflict")
      .map((q) => ({
        ...q,
        localValue: clone(q.body.payload),
        serverValue: clone(serverValue(r, q)),
      }));
    this.state = {
      tables: view(r),
      ready: !!r.epoch,
      connected,
      pending: r.outbox.length + savedReceipts.length,
      conflicts: [...conflicts, ...savedReceipts],
      epoch: r.epoch,
      programRevision: r.revisions.program || 0,
      ...(error ? { error } : {}),
    };
    for (const f of this.listeners) f(this.state);
  }
  private async changed(r: Replica) {
    await save(r);
    this.publishReplica(r);
    this.channel?.postMessage("changed");
  }
  private async lock<T>(fn: () => Promise<T>): Promise<T> {
    if (!navigator.locks)
      throw new Error("This browser does not support safe multi-tab storage.");
    return navigator.locks.request("strength-guru-replica-data", fn);
  }
  initialize(): Promise<void> {
    return (this.init ??= (async () => {
      await this.publish();
      void navigator.storage?.persist?.().catch(() => false);
      void this.sync().catch(() => {});
      this.timer = setInterval(() => {
        void this.sync().catch(() => {});
      }, 15000);
      window.addEventListener("online", () => {
        void this.sync().catch(() => {});
      });
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "visible")
          void this.sync().catch(() => {});
      });
    })().catch((e) => {
      this.init = undefined;
      this.fail(e);
      throw e;
    }));
  }
  private async pull(r: Replica): Promise<void> {
    let page: Row;
    let detached = false;
    let copied = new Set<string>();
    do {
      const params = new URLSearchParams();
      if (r.epoch) params.set("epoch", r.epoch);
      if (r.cursor !== undefined) params.set("cursor", String(r.cursor));
      page = await request(`sync?${params}`);
      if (r.epoch && r.epoch !== page.epoch && r.outbox.length)
        throw new ApiError(
          "dataset_changed",
          "The server database was restored. Export or discard pending changes before reloading.",
          409,
        );
      if (page.snapshot) {
        detached = true;
        copied = new Set(Object.keys(keys));
      } else {
        for (const change of page.changes || []) {
          const table = change.table as string;
          if (table === "sg_revisions") continue;
          if (!keys[table]) throw new Error(`Unknown sync table ${table}`);
          if (!detached) {
            r.tables = { ...r.tables };
            detached = true;
          }
          if (!copied.has(table)) {
            r.tables[table] = [...r.tables[table]];
            copied.add(table);
          }
        }
      }
      applyPage(r, page);
    } while (page.hasMore);
  }
  private async pullAndCommit(): Promise<void> {
    const staged = await read();
    const originalEpoch = staged.epoch;
    // Fetch every page into a private view, then publish it in one commit.
    await this.pull(staged);
    await this.lock(async () => {
      const latest = await read();
      if (
        originalEpoch &&
        staged.epoch !== originalEpoch &&
        latest.outbox.length
      ) {
        throw new ApiError(
          "dataset_changed",
          "The server database was restored. Export or discard pending changes before reloading.",
          409,
        );
      }
      latest.tables = staged.tables;
      latest.revisions = staged.revisions;
      latest.epoch = staged.epoch;
      latest.cursor = staged.cursor;
      if (latest.restorePending && staged.epoch !== latest.restorePending)
        delete latest.restorePending;
      await this.changed(latest);
    });
  }
  private async finalizeAccepted(): Promise<void> {
    await this.lock(async () => {
      const r = await read();
      for (const q of r.outbox.filter((x) => x.state === "accepted")) {
        const response = q.response;
        if (!response)
          throw new Error("Missing acknowledgement for pending change.");
        if (q.body.type === "getOrCreateSessionLog" && response.result?.id) {
          const old = idForSession(q.body.payload),
            actual = response.result.id;
          if (old !== actual)
            for (const next of r.outbox) {
              if (
                next.state === "pending" &&
                !next.sent &&
                next.body.payload.sessionId === old
              ) {
                next.body.payload.sessionId = actual;
                next.resource = resource(
                  next.body.type,
                  next.body.payload,
                  view(r),
                );
                next.body.expectedRevision = r.revisions[next.resource] || 0;
              }
            }
        }
        for (const next of r.outbox)
          if (
            next.state === "pending" &&
            !next.sent &&
            !next.guardedProgramEdit &&
            next.resource === q.resource &&
            next.body.expectedRevision === q.body.expectedRevision
          )
            next.body.expectedRevision = response.revision;
        if (q.resource === "program") {
          r.results = { ...(r.results || {}), [q.id]: response.result };
          r.resultSignatures = {
            ...(r.resultSignatures || {}),
            [q.id]: actionSignature(q.body.type, q.body.payload),
          };
          r.resultEpochs = { ...(r.resultEpochs || {}), [q.id]: q.body.epoch };
          r.resultBodies = { ...(r.resultBodies || {}), [q.id]: q.body };
        }
        r.outbox = r.outbox.filter((x) => x.id !== q.id);
      }
      await this.changed(r);
    });
  }
  private async synchronize(): Promise<void> {
    try {
      await this.pullAndCommit();
      await this.finalizeAccepted();
      while (true) {
        const q = await this.lock(async () => {
          const r = await read();
          const blocked = new Set<string>();
          let selected: Queued | undefined;
          for (const item of r.outbox) {
            if (item.state === "conflict") {
              blocked.add(item.resource);
              continue;
            }
            if (item.state !== "pending" || blocked.has(item.resource))
              continue;
            if (
              item.body.type === "upsertSetEntry" &&
              r.outbox.some(
                (x) =>
                  x.state === "conflict" &&
                  x.body.type === "getOrCreateSessionLog" &&
                  idForSession(x.body.payload) === item.body.payload.sessionId,
              )
            )
              continue;
            selected = item;
            break;
          }
          if (!selected) return undefined;
          selected.sent = true;
          await this.changed(r);
          return clone(selected);
        });
        if (!q) break;
        try {
          const response = await request("commands", "POST", q.body);
          await this.lock(async () => {
            const r = await read();
            const current = r.outbox.find((x) => x.id === q.id);
            if (current) {
              current.state = "accepted";
              current.response = response;
              await this.changed(r);
            }
          });
          await this.pullAndCommit();
          await this.finalizeAccepted();
        } catch (e) {
          if (!(e instanceof ApiError) || ![400, 409].includes(e.status))
            throw e;
          await this.lock(async () => {
            const r = await read();
            const current = r.outbox.find((x) => x.id === q.id);
            if (current && current.state !== "accepted") {
              current.state = "conflict";
              const staleProgram =
                current.guardedProgramEdit && e.code === "conflict";
              current.error = staleProgram ? changedProgramMessage : e.message;
              current.code = staleProgram ? "program_changed" : e.code;
              await this.changed(r);
            }
          });
          // Restore errors cannot be resolved by trying other queued requests.
          if (e.code === "dataset_changed") throw e;
        }
      }
      await this.pullAndCommit();
      await this.publish(undefined, true);
    } catch (e) {
      await this.publish(e instanceof Error ? e.message : String(e), false);
      throw e;
    }
  }
  sync(): Promise<void> {
    if (!navigator.locks) {
      const error = new Error(
        "This browser does not support safe multi-tab storage.",
      );
      this.fail(error);
      return Promise.reject(error);
    }
    if (this.flight) {
      this.again = true;
      return this.flight;
    }
    return (this.flight = navigator.locks
      .request("strength-guru-replica-sync", async () => {
        do {
          this.again = false;
          await this.synchronize();
        } while (this.again);
      })
      .finally(() => {
        this.flight = undefined;
      }));
  }
  async command(
    type: string,
    payload: Row,
    expected?: ProgramVersion,
  ): Promise<any> {
    if (!logging.has(type)) {
      const p = clone(payload),
        signature = actionSignature(type, p);
      const key = expected
        ? JSON.stringify([signature, expected.epoch, expected.programRevision])
        : signature;
      const running = this.actions.get(key);
      if (running) return running;
      const action = this.programCommand(type, p, signature, expected);
      this.actions.set(key, action);
      try {
        return await action;
      } finally {
        if (this.actions.get(key) === action) this.actions.delete(key);
      }
    }
    const queued = await this.lock(async () => {
      const r = await read();
      if (r.restorePending)
        throw new Error(
          "A restore is awaiting confirmation. Reconnect before making changes.",
        );
      if (!r.epoch)
        throw new Error("Connect once to download your training data.");
      const p = clone(payload);
      const tables = view(r);
      if (type === "getOrCreateSessionLog") {
        const existing = tables.session_logs.find(
          (x) =>
            x.mesocycle_id === p.mesoId &&
            x.week_idx === p.weekIdx &&
            x.day_idx === p.dayIdx,
        );
        if (existing) return { result: rowSession(existing) };
        p.startedAt ??= new Date().toISOString();
      }
      if (type === "upsertSetEntry") p.loggedAt ??= new Date().toISOString();
      const res = resource(type, p, tables);
      if (type === "deleteSetEntry") p.resource = res;
      const body: CommandBody = {
        operationId: crypto.randomUUID(),
        epoch: r.epoch,
        type,
        payload: p,
        expectedRevision: r.revisions[res] || 0,
      };
      body.expectedProgramRevision = r.revisions.program || 0;
      const q: Queued = {
        id: body.operationId,
        resource: res,
        body,
        state: "pending",
        sent: false,
      };
      const result = overlay(tables, q);
      r.outbox.push(q);
      await this.changed(r);
      return { id: q.id, result };
    });
    if (!queued.id) return queued.result;
    queueMicrotask(() => {
      void this.sync().catch(() => {});
    });
    return queued.result;
  }
  private async programCommand(
    type: string,
    payload: Row,
    signature: string,
    expected?: ProgramVersion,
  ): Promise<any> {
    const matchesVersion = (body?: CommandBody) =>
      !expected ||
      (body?.epoch === expected.epoch &&
        body.expectedRevision === expected.programRevision);
    const find = (r: Replica): string | undefined =>
      Object.entries(r.resultSignatures || {}).find(
        ([id, saved]) =>
          saved === signature && matchesVersion(r.resultBodies?.[id]),
      )?.[0] ||
      r.outbox.find(
        (q) =>
          q.resource === "program" &&
          matchesVersion(q.body) &&
          actionSignature(q.body.type, q.body.payload) === signature,
      )?.id;
    // Find outstanding work before syncing: background sync may have already
    // accepted it, but its result still belongs to this original action.
    let id = await this.lock(async () => find(await read()));
    if (!id) {
      await this.sync();
      id = await this.lock(async () => {
        const r = await read();
        const existing = find(r);
        if (existing) return existing;
        if (r.restorePending)
          throw new Error(
            "A restore is awaiting confirmation. Reconnect before making changes.",
          );
        if (receipts(r).some((x) => x.code === "dataset_changed"))
          throw new Error(
            "Review and discard results from the previous server dataset before making program changes.",
          );
        if (r.outbox.length)
          throw new Error(
            "Resolve pending workout changes before editing programs.",
          );
        if (!r.epoch)
          throw new Error("Connect once to download your training data.");
        const revision = r.revisions.program || 0;
        if (expected && expected.epoch !== r.epoch)
          throw new ApiError("dataset_changed", changedProgramMessage, 409);
        if (expected && expected.programRevision !== revision)
          throw new ApiError("program_changed", changedProgramMessage, 409);
        const body: CommandBody = {
          operationId: crypto.randomUUID(),
          epoch: r.epoch,
          type,
          payload,
          expectedRevision: revision,
        };
        r.outbox.push({
          id: body.operationId,
          resource: "program",
          body,
          state: "pending",
          sent: false,
          ...(expected ? { guardedProgramEdit: true } : {}),
        });
        await this.changed(r);
        return body.operationId;
      });
    }
    // Check the current dataset before treating a saved result as success.
    await this.sync();
    const hasResult = await this.lock(async () => {
      const r = await read();
      const conflict = r.outbox.find(
        (q) => q.id === id && q.state === "conflict",
      );
      if (conflict?.guardedProgramEdit && conflict.code === "program_changed")
        throw new ApiError("program_changed", changedProgramMessage, 409);
      return Object.prototype.hasOwnProperty.call(r.results || {}, id!);
    });
    if (!hasResult)
      throw new Error(
        "The change is pending. Reconnect to confirm its result.",
      );
    return this.lock(async () => {
      const r = (await read()) as Replica & {
        results?: Row;
        resultSignatures?: Record<string, string>;
      };
      if (!Object.prototype.hasOwnProperty.call(r.results || {}, id!))
        throw new Error("This change was already confirmed in another tab.");
      if (!r.resultEpochs?.[id!] || r.resultEpochs[id!] !== r.epoch)
        throw new Error(
          "This result belongs to a different server dataset. Export or discard it before repeating the action.",
        );
      const value = r.results![id!];
      delete r.results![id!];
      delete r.resultSignatures?.[id!];
      delete r.resultEpochs?.[id!];
      delete r.resultBodies?.[id!];
      await this.changed(r);
      return value;
    });
  }
  async exportPending(): Promise<string> {
    const r = await read();
    return JSON.stringify([...r.outbox, ...receipts(r)], null, 2);
  }
  async restore(token: string): Promise<void> {
    if (!navigator.locks)
      throw new Error("This browser does not support safe multi-tab storage.");
    await navigator.locks.request("strength-guru-replica-sync", async () => {
      await this.synchronize();
      await this.lock(async () => {
        const r = await read();
        if (r.outbox.length)
          throw new Error(
            "Resolve or export pending changes before restoring.",
          );
        if (Object.keys(r.results || {}).length)
          throw new Error(
            "Resolve or export and discard unconfirmed results before restoring.",
          );
        if (!r.epoch) throw new Error("Connect before restoring a backup.");
        const epoch = r.epoch;
        const alreadyPending = !!r.restorePending;
        // A lost restore response leaves writes paused until the new epoch is observed.
        r.restorePending = epoch;
        await this.changed(r);
        try {
          await request("backups/restore", "POST", {
            token,
            confirmed: true,
            expectedEpoch: epoch,
          });
        } catch (e) {
          if (
            !alreadyPending &&
            e instanceof ApiError &&
            e.status >= 400 &&
            e.status < 500 &&
            e.status !== 408 &&
            e.code !== "dataset_changed"
          ) {
            delete r.restorePending;
            await this.changed(r);
          }
          throw e;
        }
        await this.pull(r);
        if (r.epoch === epoch)
          throw new Error(
            "Restore is awaiting confirmation. Reconnect before making changes.",
          );
        delete r.restorePending;
        await this.changed(r);
      });
    });
    await this.sync();
  }
  async discard(id: string): Promise<void> {
    if (!navigator.locks)
      throw new Error("This browser does not support safe multi-tab storage.");
    await navigator.locks.request("strength-guru-replica-sync", async () => {
      const q = (await read()).outbox.find((x) => x.id === id);
      if (!q) {
        await this.lock(async () => {
          const r = await read();
          delete r.results?.[id];
          delete r.resultSignatures?.[id];
          delete r.resultEpochs?.[id];
          delete r.resultBodies?.[id];
          await this.changed(r);
        });
        return;
      }
      if (q.sent && q.state !== "conflict") {
        try {
          await this.synchronize();
        } catch (e) {
          if (!(e instanceof ApiError) || e.code !== "dataset_changed")
            throw new Error(
              "Reconnect to confirm whether this change was saved before discarding it.",
            );
        }
        if (!(await read()).outbox.some((x) => x.id === id))
          throw new Error("This change was already saved on the server.");
      }
      await this.lock(async () => {
        const r = await read();
        r.outbox = r.outbox.filter((x) => x.id !== id);
        await this.changed(r);
      });
    });
    await this.sync();
  }
  async keepLocal(id: string): Promise<void> {
    await this.sync();
    await this.lock(async () => {
      const r = await read();
      const q = r.outbox.find((x) => x.id === id);
      if (!q) throw new Error("Pending change not found.");
      if (
        q.code === "program_changed" ||
        q.code === "dataset_changed" ||
        q.code === "deleted_reference" ||
        q.body.epoch !== r.epoch
      )
        throw new Error(
          "The program changed. Export or discard this edit and review the workout.",
        );
      if (
        (logging.has(q.body.type) &&
          q.body.expectedProgramRevision !== (r.revisions.program || 0)) ||
        (q.guardedProgramEdit &&
          q.body.expectedRevision !== (r.revisions.program || 0))
      )
        throw new Error(
          "The program changed. Export or discard this edit and review the workout.",
        );
      q.id = crypto.randomUUID();
      q.body.operationId = q.id;
      q.body.expectedRevision = r.revisions[q.resource] || 0;
      q.state = "pending";
      q.sent = false;
      delete q.error;
      delete q.code;
      await this.changed(r);
    });
    await this.sync();
  }
}
export const training = new Training();
