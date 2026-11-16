import { afterEach, describe, expect, it, vi } from "vitest";

function fakeStorage(oldReplica?: unknown) {
  const values: Record<string, unknown> = oldReplica
    ? { replica: oldReplica }
    : {};
  const writes: Record<string, number> = {};
  let fail = false;
  let version = oldReplica ? 1 : 0;
  let upgradeTransaction: any;
  const db = {
    createObjectStore(name: string) {
      return upgradeTransaction.objectStore(name);
    },
    close() {},
    transaction() {
      const pending: Record<string, unknown> = {};
      let scheduled = false;
      const tx: any = {
        objectStore: (name: string) => ({
          get: () => {
            const req: any = {};
            queueMicrotask(() => {
              req.result = structuredClone(values[name]);
              req.onsuccess?.();
            });
            return req;
          },
          put: (v: unknown) => {
            pending[name] = structuredClone(v);
            if (!scheduled) {
              scheduled = true;
              queueMicrotask(() => {
                if (fail) {
                  fail = false;
                  tx.error = new Error("quota exceeded");
                  tx.onabort?.();
                  return;
                }
                for (const [key, item] of Object.entries(pending)) {
                  values[key] = item;
                  writes[key] = (writes[key] || 0) + 1;
                }
                tx.oncomplete?.();
              });
            }
          },
        }),
      };
      return tx;
    },
  };
  return {
    writes,
    failNextWrite: () => {
      fail = true;
    },
    open: () => {
      const req: any = { result: db };
      queueMicrotask(() => {
        upgradeTransaction = db.transaction();
        req.transaction = upgradeTransaction;
        if (version < 2) req.onupgradeneeded?.({ oldVersion: version });
        version = 2;
        queueMicrotask(() => queueMicrotask(() => req.onsuccess?.()));
      });
      return req;
    },
  };
}
function fakeLocks() {
  const held = new Map<string, Promise<unknown>>();
  return {
    request<T>(name: string, fn: () => Promise<T>): Promise<T> {
      const next = (held.get(name) || Promise.resolve())
        .catch(() => {})
        .then(fn);
      held.set(name, next);
      return next;
    },
  };
}

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.resetModules();
});

describe("durable online commands", () => {
  it("saves offline edits without rewriting the canonical snapshot and rolls back failures", async () => {
    vi.useFakeTimers();
    const storage = fakeStorage();
    vi.stubGlobal("indexedDB", storage);
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    let online = true;
    vi.stubGlobal("fetch", async () => {
      if (!online) throw new Error("offline");
      return Response.json({
        epoch: "dataset",
        cursor: 0,
        snapshot: tables,
        revisions: [],
      });
    });
    const { training } = await import("./index");
    let state: any;
    training.subscribe((s) => {
      state = s;
    });
    await training.initialize();
    await training.sync();
    const before = storage.writes.canonical;
    online = false;
    await training.command("getOrCreateSessionLog", {
      mesoId: "meso",
      weekIdx: 0,
      dayIdx: 0,
    });
    await training.sync().catch(() => {});
    expect(storage.writes.canonical).toBe(before);
    expect(state.tables.session_logs).toHaveLength(1);
    storage.failNextWrite();
    await expect(
      training.command("getOrCreateSessionLog", {
        mesoId: "meso",
        weekIdx: 0,
        dayIdx: 1,
      }),
    ).rejects.toThrow("quota exceeded");
    expect(state.tables.session_logs).toHaveLength(1);
    expect(JSON.parse(await training.exportPending())).toHaveLength(1);
  });

  it("migrates a v1 replica into the split stores without losing pending edits", async () => {
    vi.useFakeTimers();
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    tables.mesocycles = [{ id: "old", name: "Kept" }];
    const body = {
      operationId: "queued",
      epoch: "old-epoch",
      type: "getOrCreateSessionLog",
      payload: {
        mesoId: "old",
        weekIdx: 0,
        dayIdx: 0,
        startedAt: "2026-01-01T00:00:00Z",
      },
      expectedRevision: 0,
      expectedProgramRevision: 0,
    };
    vi.stubGlobal(
      "indexedDB",
      fakeStorage({
        epoch: "old-epoch",
        cursor: 3,
        tables,
        revisions: {},
        outbox: [
          {
            id: "queued",
            resource: "session:old:0:0",
            body,
            state: "pending",
            sent: false,
          },
        ],
      }),
    );
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    vi.stubGlobal("fetch", async () => {
      throw new Error("offline");
    });
    const { training } = await import("./index");
    let state: any;
    training.subscribe((s) => {
      state = s;
    });
    await training.initialize();
    await training.sync().catch(() => {});
    expect(state.tables.mesocycles[0].name).toBe("Kept");
    expect(state.tables.session_logs).toHaveLength(1);
    expect(JSON.parse(await training.exportPending())[0].id).toBe("queued");
  });

  it("does not expose partially applied pages when a pull fails", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    tables.mesocycles = [{ id: "meso", name: "Original" }];
    let partial = false;
    vi.stubGlobal("fetch", async (path: string) => {
      if (!partial)
        return Response.json({
          epoch: "dataset",
          cursor: 0,
          snapshot: tables,
          revisions: [],
        });
      if (String(path).includes("cursor=1"))
        throw new Error("page unavailable");
      return Response.json({
        epoch: "dataset",
        cursor: 1,
        hasMore: true,
        changes: [
          {
            table: "mesocycles",
            deleted: 0,
            data: JSON.stringify({ id: "meso", name: "Partial" }),
          },
        ],
      });
    });
    const { training } = await import("./index");
    let state: any;
    training.subscribe((s) => {
      state = s;
    });
    await training.initialize();
    await training.sync();
    partial = true;
    await expect(training.sync()).rejects.toThrow("page unavailable");
    expect(state.tables.mesocycles[0].name).toBe("Original");
  });

  it("invalidates cached tables after another tab saves a new generation", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    tables.mesocycles = [{ id: "meso", name: "Original" }];
    let online = true;
    vi.stubGlobal("fetch", async () => {
      if (!online) throw new Error("offline");
      return Response.json({
        epoch: "dataset",
        cursor: 0,
        snapshot: tables,
        revisions: [],
      });
    });
    const { training: first } = await import("./index");
    let state: any;
    first.subscribe((s) => {
      state = s;
    });
    await first.initialize();
    await first.sync();
    vi.resetModules();
    const { training: second } = await import("./index");
    await second.initialize();
    await second.sync();
    tables.mesocycles = [{ id: "meso", name: "Updated" }];
    await second.sync();
    online = false;
    await first.command("getOrCreateSessionLog", {
      mesoId: "meso",
      weekIdx: 0,
      dayIdx: 0,
    });
    expect(state.tables.mesocycles[0].name).toBe("Updated");
    await first.sync().catch(() => {});
  });

  it("recovers the same result after a lost acknowledgement without applying twice", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    let count = 0,
      lose = true;
    const results = new Map<string, unknown>();
    vi.stubGlobal("fetch", async (path: string, options?: RequestInit) => {
      if (String(path).startsWith("/api/v1/sync"))
        return Response.json({
          epoch: "dataset",
          cursor: 0,
          snapshot: tables,
          revisions: [],
        });
      const body = JSON.parse(String(options?.body));
      if (!results.has(body.operationId)) {
        count++;
        results.set(body.operationId, { id: `created-${count}` });
      }
      if (lose) {
        lose = false;
        throw new Error("acknowledgement lost");
      }
      return Response.json({
        result: results.get(body.operationId),
        resource: "program",
        revision: count,
      });
    });
    const { training } = await import("./index");
    await training.initialize();
    await training.sync();
    await expect(
      training.command("createMeso", {
        name: "Block",
        settings: { b: 2, a: 1 },
      }),
    ).rejects.toThrow("acknowledgement lost");
    vi.resetModules();
    const { training: reopened } = await import("./index");
    await reopened.initialize();
    await reopened.sync();
    expect(
      await reopened.command("createMeso", {
        settings: { a: 1, b: 2 },
        name: "Block",
      }),
    ).toEqual({ id: "created-1" });
    expect(count).toBe(1);
    expect(
      await reopened.command("createMeso", {
        name: "Block",
        settings: { a: 1, b: 2 },
      }),
    ).toEqual({ id: "created-2" });
    expect(count).toBe(2);
  });

  it("clears a definite restore rejection and permits local logging", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    vi.stubGlobal("fetch", async (path: string) =>
      String(path).startsWith("/api/v1/sync")
        ? Response.json({
            epoch: "dataset",
            cursor: 0,
            snapshot: tables,
            revisions: [],
          })
        : Response.json(
            { code: "expired_import", message: "Select the backup again." },
            { status: 400 },
          ),
    );
    const { training } = await import("./index");
    await training.initialize();
    await training.sync();
    await expect(training.restore("expired")).rejects.toThrow(
      "Select the backup again.",
    );
    const session = await training.command("getOrCreateSessionLog", {
      mesoId: "meso",
      weekIdx: 0,
      dayIdx: 0,
    });
    expect(session.id).toBeTruthy();
    await training.sync();
  });

  it("retains an old result for review rather than confirming it after restore", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, any[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    let epoch = "original",
      count = 0,
      lose = true;
    const operations = new Map<string, unknown>();
    vi.stubGlobal("fetch", async (path: string, options?: RequestInit) => {
      if (String(path).startsWith("/api/v1/sync"))
        return Response.json({
          epoch,
          cursor: 0,
          snapshot: tables,
          revisions: [],
        });
      const body = JSON.parse(String(options?.body));
      if (!operations.has(body.operationId)) {
        count++;
        operations.set(body.operationId, { id: `created-${count}` });
      }
      if (lose) {
        lose = false;
        throw new Error("acknowledgement lost");
      }
      return Response.json({
        result: operations.get(body.operationId),
        resource: "program",
        revision: count,
      });
    });
    const { training } = await import("./index");
    let state: any;
    training.subscribe((s) => {
      state = s;
    });
    await training.initialize();
    await training.sync();
    await expect(
      training.command("createMeso", { name: "Block" }),
    ).rejects.toThrow("acknowledgement lost");
    await training.sync();
    await expect(training.restore("token")).rejects.toThrow(
      "unconfirmed results",
    );
    epoch = "restored";
    await training.sync();
    await expect(
      training.command("createMeso", { name: "Block" }),
    ).rejects.toThrow("different server dataset");
    expect(count).toBe(1);
    expect(state.conflicts).toHaveLength(1);
    expect(state.conflicts[0].code).toBe("dataset_changed");
    const exported = JSON.parse(await training.exportPending());
    expect(exported[0].body.epoch).toBe("original");
    expect(exported[0].result).toEqual({ id: "created-1" });
    await training.discard(state.conflicts[0].id);
    expect(await training.command("createMeso", { name: "Block" })).toEqual({
      id: "created-2",
    });
  });

  it("compares a conflicting local set with the canonical server value", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", { locks: fakeLocks() });
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const tables: Record<string, unknown[]> = Object.fromEntries(
      [
        "mesocycles",
        "exercises",
        "exercise_slots",
        "week_targets",
        "program_days",
        "day_overrides",
        "session_logs",
        "set_entries",
        "settings",
      ].map((k) => [k, []]),
    );
    tables.set_entries = [
      {
        id: "set",
        session_id: "session",
        slot_id: "slot",
        exercise_id: "exercise",
        set_index: 0,
        weight: 80,
        done: 1,
      },
    ];
    vi.stubGlobal("fetch", async (path: string) =>
      String(path).startsWith("/api/v1/sync")
        ? Response.json({
            epoch: "dataset",
            cursor: 0,
            snapshot: tables,
            revisions: [],
          })
        : Response.json(
            { code: "conflict", message: "Changed on another device." },
            { status: 409 },
          ),
    );
    const { training } = await import("./index");
    let state: any;
    training.subscribe((s) => {
      state = s;
    });
    await training.initialize();
    await training.sync();
    await training.command("upsertSetEntry", {
      sessionId: "session",
      slotId: "slot",
      exerciseId: "exercise",
      setIndex: 0,
      weight: 90,
      done: true,
    });
    await training.sync();
    expect(state.tables.set_entries[0].weight).toBe(90);
    expect(state.conflicts[0].localValue.weight).toBe(90);
    expect(state.conflicts[0].serverValue.weight).toBe(80);
  });

  it("surfaces an unsupported browser instead of leaving first use spinning", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("indexedDB", fakeStorage());
    vi.stubGlobal("BroadcastChannel", undefined);
    vi.stubGlobal("navigator", {});
    vi.stubGlobal("window", { addEventListener() {} });
    vi.stubGlobal("document", {
      addEventListener() {},
      visibilityState: "visible",
    });
    const { training } = await import("./index");
    let error: string | undefined;
    training.subscribe((s) => {
      error = s.error;
    });
    await training.initialize();
    expect(error).toContain("safe multi-tab storage");
  });
});
