// Job request bodies and editable reviews survive tab closure and ambiguous responses.
let connection: Promise<IDBDatabase> | undefined;
function database() {
  return (connection ??= new Promise<IDBDatabase>((resolve, reject) => {
    const r = indexedDB.open("strength-guru-workflows", 1);
    r.onupgradeneeded = () => r.result.createObjectStore("drafts");
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  }));
}
export async function readDraft<T = any>(key: string): Promise<T | undefined> {
  const db = await database();
  return new Promise((resolve, reject) => {
    const tx = db.transaction("drafts", "readonly");
    const r = tx.objectStore("drafts").get(key);
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}
export async function writeDraft(key: string, value: any) {
  const db = await database();
  return new Promise<void>((resolve, reject) => {
    const tx = db.transaction("drafts", "readwrite");
    if (value === undefined) tx.objectStore("drafts").delete(key);
    else tx.objectStore("drafts").put(structuredClone(value), key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export async function listDrafts(
  prefix: string,
): Promise<{ key: string; value: any }[]> {
  const db = await database();
  return new Promise((resolve, reject) => {
    const values: { key: string; value: any }[] = [];
    const tx = db.transaction("drafts", "readonly");
    const r = tx.objectStore("drafts").openCursor();
    r.onsuccess = () => {
      const c = r.result;
      if (c) {
        if (String(c.key).startsWith(prefix))
          values.push({ key: String(c.key), value: c.value });
        c.continue();
      } else resolve(values);
    };
    r.onerror = () => reject(r.error);
  });
}

export function accountDrafts(accountId: string) {
  const namespace = `account:${accountId}:`;
  return {
    readDraft: <T>(key: string) => readDraft<T>(namespace + key),
    writeDraft: (key: string, value: any) => writeDraft(namespace + key, value),
    listDrafts: async (prefix: string) =>
      (await listDrafts(namespace + prefix)).map(({ key, value }) => ({
        key: key.slice(namespace.length),
        value,
      })),
  };
}

export async function legacyDrafts() {
  return (await listDrafts("")).filter(({ key }) => !key.startsWith("account:"));
}

export async function adoptLegacyDrafts(accountId: string) {
  const { writeDraft: write } = accountDrafts(accountId);
  for (const { key, value } of await legacyDrafts()) {
    if ((await accountDrafts(accountId).readDraft(key)) === undefined)
      await write(key, value);
  }
  for (const name of ["sg-tab", "sg-workflow"]) {
    const legacy = sessionStorage.getItem(name);
    if (legacy !== null && sessionStorage.getItem(`${name}:${accountId}`) === null)
      sessionStorage.setItem(`${name}:${accountId}`, legacy);
  }
}
