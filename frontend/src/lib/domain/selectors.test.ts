import { afterEach, expect, it, vi } from 'vitest';
import { plan, todayKey, program } from './training';

afterEach(() => vi.useRealTimers());

it('uses calendar days across a daylight-saving transition', () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(2026, 2, 30, 12));
  const start = new Date(2026, 2, 23);
  expect(todayKey({ start_date: start.getTime() / 1000, num_weeks: 4 })).toEqual({ week: 1, day: 0 });
  expect(todayKey({ start_date: new Date(2026, 3, 1).getTime() / 1000, num_weeks: 4 })).toBeNull();
  expect(todayKey({ start_date: start.getTime() / 1000, num_weeks: 1 })).toBeNull();
});

it('preserves explicit rest overrides and slot ordering without resurrecting deleted references', () => {
  const tables = {
    day_overrides: [
      { mesocycle_id: 'm', week_idx: -1, day_idx: 0, exercise_ids_csv: 'b,deleted,a' },
      { mesocycle_id: 'm', week_idx: 1, day_idx: 0, exercise_ids_csv: '' },
    ],
    exercises: [{ id: 'e', name: 'Bench', group: 'chest' }],
    exercise_slots: [{ id: 'a', exercise_id: 'e' }, { id: 'b', exercise_id: 'e' }],
  };
  expect(plan(tables, 'm', 0, 0).map(e => e.slotId)).toEqual(['b', 'a']);
  expect(plan(tables, 'm', 1, 0)).toEqual([]);
  expect(program(tables, 'm', 0).map(e => e.slotId)).toEqual(['b', 'a']);
});
