export type Row = Record<string, any>;
export type Tables = Record<string, Row[]>;
export const days = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
];
export const groups = [
  "chest",
  "shoulders",
  "back",
  "biceps",
  "triceps",
  "forearms",
  "quads",
  "hamstrings",
  "glutes",
  "abs",
  "calves",
  "other",
  "rest",
];
export const colors = [
  "#E89B9B",
  "#E8B29B",
  "#9BB6E8",
  "#9BE8E8",
  "#9BE8B2",
  "#B2E89B",
  "#EBD479",
  "#E89BD4",
  "#A8C9A0",
  "#D4E89B",
  "#C99BA8",
  "#E8E4DC",
  "#C8C2B6",
];
export const lightTints = [
  "#FBE9E9",
  "#FBF1E9",
  "#E8EFFB",
  "#E9FBFB",
  "#E9FBF1",
  "#F1FBE9",
  "#FBF4D9",
  "#FBE9F5",
  "#E6F1E1",
  "#F5FBE9",
  "#FBE9EF",
  "#F2EEE5",
  "#EDE9DF",
];
export const darkTints = [
  "#2A1818",
  "#2A2018",
  "#182027",
  "#182727",
  "#182720",
  "#202718",
  "#292412",
  "#2A1825",
  "#192218",
  "#252718",
  "#2A181E",
  "#232118",
  "#1E1D1A",
];
export function groupName(g: string) {
  const aliases: Row = {
    push: "chest",
    pull: "back",
    legs: "quads",
    arms: "biceps",
  };
  const s = String(g || "other").toLowerCase();
  return groups.includes(s) ? s : aliases[s] || "other";
}
export const title = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
export const groupStyle = (g: string) => {
  const i = groups.indexOf(groupName(g));
  return `--group:${colors[i]};--tint-light:${lightTints[i]};--tint-dark:${darkTints[i]}`;
};
export function primary(items: Row[]) {
  if (!items.length) return "rest";
  const counts: Row = {};
  let best = "other",
    max = 0;
  for (const e of items) {
    const g = groupName(e.group);
    counts[g] = (counts[g] || 0) + 1;
    if (counts[g] > max) {
      best = g;
      max = counts[g];
    }
  }
  return best;
}
export const truth = (v: any) => v === true || v === 1;
export const list = (v: any): number[] =>
  Array.isArray(v)
    ? v.map(Number)
    : String(v ?? "")
        .split(",")
        .filter(Boolean)
        .map(Number);
export function dateValue(v: any): Date {
  return new Date(typeof v === "number" && v < 1e12 ? v * 1000 : v);
}
export function todayKey(m: Row | null) {
  if (!m) return null;
  const d = new Date(),
    s = dateValue(m.start_date);
  const diff = Math.floor(
    (Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) -
      Date.UTC(s.getFullYear(), s.getMonth(), s.getDate())) /
      86400000,
  );
  const week = Math.floor(diff / 7);
  return week < 0 || week >= m.num_weeks
    ? null
    : { week, day: (d.getDay() + 6) % 7 };
}
export function plan(t: Tables, m: string, week: number, day: number): Row[] {
  const ovs = t.day_overrides || [];
  const ov =
    ovs.find(
      (e) => e.mesocycle_id === m && e.week_idx === week && e.day_idx === day,
    ) ||
    ovs.find(
      (e) => e.mesocycle_id === m && e.week_idx === -1 && e.day_idx === day,
    );
  return String(ov?.exercise_ids_csv || "")
    .split(",")
    .filter(Boolean)
    .flatMap((id) => {
      const slot = (t.exercise_slots || []).find((s) => s.id === id);
      const e = (t.exercises || []).find((e) => e.id === slot?.exercise_id);
      return slot && e ? [{ ...e, slotId: slot.id }] : [];
    });
}
export function program(t: Tables, m: string, day: number): Row[] {
  const ovs = (t.day_overrides || []).filter(
    (o) => o.mesocycle_id === m && o.day_idx === day,
  );
  const baseline = ovs.find((o) => o.week_idx === -1);
  if (baseline) return plan(t, m, -1, day);
  const counts: Row = {};
  for (const o of ovs)
    counts[o.exercise_ids_csv] = (counts[o.exercise_ids_csv] || 0) + 1;
  const best = ovs
    .slice()
    .sort((a, b) => counts[b.exercise_ids_csv] - counts[a.exercise_ids_csv])[0];
  return plan(t, m, best?.week_idx ?? 0, day);
}
export function target(t: Tables, m: string, w: number, slot: string) {
  const r = (t.week_targets || []).find(
    (e) => e.mesocycle_id === m && e.week_idx === w && e.slot_id === slot,
  );
  return r ? { ...r, reps: list(r.reps), rir: list(r.rir) } : null;
}
export function label(t: Tables, m: string, day: number) {
  return (t.program_days || []).find(
    (e) => e.mesocycle_id === m && e.day_idx === day,
  )?.label;
}
export function session(t: Tables, m: string, w: number, d: number) {
  return (t.session_logs || []).find(
    (e) => e.mesocycle_id === m && e.week_idx === w && e.day_idx === d,
  );
}
export function entries(t: Tables, m: string, w: number, d: number) {
  const s = session(t, m, w, d);
  return s ? (t.set_entries || []).filter((e) => e.session_id === s.id) : [];
}
export function formatReps(r: number[]) {
  if (!r.length) return "—";
  if (r.every((x) => x === r[0])) return `${r.length}×${r[0]}`;
  if (r.length > 1 && r.slice(1).every((x) => x === r[1]))
    return `${r[0]} + ${r.length - 1}×${r[1]}`;
  const s = r.join(",");
  return s.length > 10 ? `${r[0]}..${r.at(-1)}` : s;
}
export function formatRir(r: number[]) {
  return !r.length
    ? "—"
    : r.every((x) => x === r[0])
      ? `RIR ${r[0]}`
      : `RIR ${r.join(",")}`;
}
export const clamp = (n: number, min: number, max: number) =>
  Math.min(max, Math.max(min, n));
export function estimate1Rm(
  weight: number,
  reps: number,
  rir: number,
  f: string,
) {
  const r = reps + rir;
  return r <= 0
    ? weight
    : f === "epley"
      ? weight * (1 + r / 30)
      : r >= 37
        ? weight
        : (weight * 36) / (37 - r);
}
export function weightForReps(
  one: number,
  reps: number,
  rir: number,
  f: string,
) {
  return f === "epley"
    ? one / (1 + (reps + rir) / 30)
    : (one * (37 - reps - rir)) / 36;
}
export function repsForWeight(one: number, w: number, f: string) {
  return one <= 0 || w <= 0
    ? 0
    : clamp(
        Math.round(f === "epley" ? (one / w - 1) * 30 : 37 - (36 * w) / one),
        0,
        50,
      );
}
export function progression(config: Row[], weeks: number, deloads: number[]) {
  const n = clamp(weeks - deloads.length, 1, weeks);
  const lerp = (
    a: number,
    b: number,
    i: number,
    n: number,
    lo: number,
    hi: number,
  ) => clamp(n <= 1 ? a : Math.round(a + (i * (b - a)) / (n - 1)), lo, hi);
  return Array.from({ length: weeks }, (_, w) => {
    const p = Array.from({ length: w }, (_, i) => i).filter(
      (i) => !deloads.includes(i),
    ).length;
    const ri = deloads.includes(w) ? clamp(p - 1, 0, n - 1) : p;
    const ir = w > 0 && deloads.includes(w - 1) ? clamp(p - 1, 0, n - 1) : p;
    return {
      weekIdx: w,
      reps: config.map((s) =>
        lerp(
          s.startReps,
          s.endReps,
          Math.floor(ri / 2) + 1,
          Math.floor((n + 1) / 2) + 1,
          1,
          99,
        ),
      ),
      rir: config.map((s) =>
        deloads.includes(w)
          ? 4
          : lerp(
              s.startRir,
              s.endRir,
              Math.floor((ir + 1) / 2),
              n - Math.floor((n + 1) / 2) + 1,
              0,
              5,
            ),
      ),
    };
  });
}
export function exportPlan(t: Tables, m: Row) {
  return {
    name: m.name,
    numWeeks: m.num_weeks,
    days: days.flatMap((_, dayIdx) => {
      const overrides = (t.day_overrides || []).filter(
        (o) => o.mesocycle_id === m.id && o.day_idx === dayIdx,
      );
      if (!overrides.length) return [];
      const baseline = overrides.find((o) => o.week_idx === 0) || overrides[0];
      return [
        {
          dayIdx,
          label: label(t, m.id, dayIdx) || "",
          exercises: plan(t, m.id, baseline.week_idx, dayIdx).map((e) => ({
            name: e.name,
            muscleGroup: e.group,
            weekTargets: (t.week_targets || [])
              .filter((r) => r.mesocycle_id === m.id && r.slot_id === e.slotId)
              .map((r) => ({
                weekIdx: r.week_idx,
                reps: list(r.reps),
                rir: list(r.rir),
              })),
          })),
        },
      ];
    }),
  };
}
export function importTarget(e: Row, w: number) {
  const ts = e.weekTargets || [];
  const raw =
    ts.length === 1 ? ts[0] : ts.find((t: Row) => t.weekIdx === w) || ts.at(-1);
  return raw
    ? {
        weekIdx: w,
        reps: Array.isArray(raw.reps)
          ? raw.reps
          : Array(raw.sets || 3).fill(raw.reps || 8),
        rir: Array.isArray(raw.rir)
          ? raw.rir
          : Array(raw.sets || 3).fill(raw.rir ?? 2),
      }
    : { weekIdx: w, reps: [8, 8, 8], rir: [2, 2, 2] };
}
export function normalizePlan(p: Row) {
  return {
    ...p,
    name: p.name || "Imported Block",
    numWeeks: p.numWeeks || 4,
    days: (p.days || []).map((d: Row, i: number) => ({
      ...d,
      dayIdx: i,
      label: d.label || days[i],
      exercises: (d.exercises || []).map((e: Row) => ({
        ...e,
        muscleGroup: groupName(e.muscleGroup || e.group),
        weekTargets: Array.from({ length: p.numWeeks || 4 }, (_, w) =>
          importTarget(e, w),
        ),
      })),
    })),
    advisories: p.advisories || [],
  };
}
export function validateVolume(
  data: Row,
  experience = "intermediate",
  goal = "hypertrophy",
) {
  const mev: Row = {
    chest: 8,
    back: 10,
    shoulders: 8,
    biceps: 6,
    triceps: 6,
    quads: 8,
    hamstrings: 6,
    glutes: 6,
    calves: 6,
    abs: 6,
  };
  const mrv: Row = {
    chest: 22,
    back: 25,
    shoulders: 20,
    biceps: 20,
    triceps: 18,
    quads: 22,
    hamstrings: 20,
    glutes: 16,
    calves: 16,
    abs: 20,
  };
  const scale =
    experience === "beginner" ? 0.7 : experience === "advanced" ? 1.15 : 1;
  const result: Row[] = [];
  if (!data.days.length) return result;
  const sets: Row[] = [],
    freq: Row[] = [];
  for (let w = 0; w < data.numWeeks; w++) {
    const s: Row = {},
      f: Row = {};
    for (const d of data.days)
      for (const e of d.exercises) {
        const g = groupName(e.muscleGroup);
        if (!(g in mev)) continue;
        const n = importTarget(e, w).reps.length;
        s[g] = (s[g] || 0) + n;
        if (n) (f[g] ??= new Set()).add(d.dayIdx);
      }
    sets.push(s);
    freq.push(f);
  }
  const suffix = (ws: number[]) =>
    ws.length === data.numWeeks
      ? ""
      : ws.length >= 3 && ws.at(-1)! - ws[0] === ws.length - 1
        ? ` in weeks ${ws[0] + 1}–${ws.at(-1)! + 1}`
        : ` in week${ws.length === 1 ? "" : "s"} ${ws.map((w) => w + 1).join(", ")}`;
  const add = (severity: string, scope: string, message: string) =>
    result.push({ severity, scope, message, source: "volume" });
  for (const g of Object.keys(mev)) {
    const lo = Math.round(mev[g] * scale),
      hi = Math.round(mrv[g] * scale);
    const zero: number[] = [],
      below: number[] = [],
      above: number[] = [];
    for (let w = 0; w < data.numWeeks; w++) {
      const n = sets[w][g] || 0;
      if (
        n === 0 &&
        (["chest", "back", "quads"].includes(g) ||
          (["biceps", "triceps"].includes(g) && experience !== "beginner"))
      )
        zero.push(w);
      else if (n > 0 && n < Math.round(lo * 0.8)) below.push(w);
      else if (n > hi) above.push(w);
    }
    if (zero.length) add("warn", g, `No ${title(g)} work${suffix(zero)}.`);
    if (below.length)
      add(
        "info",
        g,
        `${title(g)}: ${sets[below[0]][g]} sets — low relative to MEV (~${lo}); compound overlap may cover the gap${suffix(below)}.`,
      );
    if (above.length)
      add(
        "warn",
        g,
        `${title(g)}: ${sets[above[0]][g]} sets — above MRV (~${hi})${suffix(above)}.`,
      );
  }
  if (data.days.filter((d: Row) => d.exercises.length).length >= 4)
    for (const g of ["chest", "back", "quads"]) {
      const ws = sets
        .map((s, w) => (s[g] > 0 && (freq[w][g]?.size || 0) < 2 ? w : -1))
        .filter((w) => w >= 0);
      if (ws.length)
        add(
          "info",
          `${g}_freq`,
          `${title(g)} trained only 1×/wk${suffix(ws)} — consider ≥2×/wk for hypertrophy.`,
        );
    }
  if (goal !== "strength") {
    const push: number[] = [],
      pull: number[] = [];
    for (let w = 0; w < data.numWeeks; w++) {
      const s = sets[w],
        a = (s.chest || 0) + (s.shoulders || 0) + (s.triceps || 0),
        b = (s.back || 0) + (s.biceps || 0);
      if (a && b) {
        if (a / b > 1.7) push.push(w);
        else if (a / b < 0.6) pull.push(w);
      }
    }
    for (const [ws, isPush] of [
      [push, true],
      [pull, false],
    ] as [number[], boolean][]) {
      if (ws.length) {
        const s = sets[ws[0]],
          a = (s.chest || 0) + (s.shoulders || 0) + (s.triceps || 0),
          b = (s.back || 0) + (s.biceps || 0);
        add(
          "warn",
          "balance",
          `${isPush ? "Push:pull" : "Pull:push"} ratio ${(isPush ? a / b : b / a).toFixed(1)}:1${suffix(ws)} — consider adding ${isPush ? "pulling" : "pressing"} volume.`,
        );
      }
    }
  }
  return result;
}
export async function api(path: string, method = "GET", body?: any) {
  const r = await fetch(`/api/v1/${path}`, {
    method,
    signal: AbortSignal.timeout(20000),
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await r.json();
  if (!r.ok)
    throw Error(
      data.message ||
        data.error?.message ||
        data.error ||
        `Request failed (${r.status})`,
    );
  return data;
}
export function download(
  value: string,
  name: string,
  type = "application/json",
) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([value], { type }));
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}
