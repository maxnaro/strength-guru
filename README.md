# Strength Guru

Strength Guru is a local-first strength tracker. It focuses on RIR-based progression, flexible program management, and a streamlined logging experience.

## Key Features

- **Pick any day to log** — Scrub to past, today, or future days. The calendar reflects real session-log state retroactively.
- **Italic placeholder hints** — See your previous session's weight and reps directly in the input field as a hint.
- **Weight auto-suggest** — Suggests the last logged weight for the current exercise across all sessions.
- **Three swap scopes** — Swap exercises for just this session, from now forward, or across the entire program.
- **Custom exercise creation** — Add any exercise (e.g., gym-specific machines) inline from any swap or program editor.
- **Day program editor** — Reorder, add, or remove exercises for any day in the meso, applied across all weeks.
- **Per-week targets** — Edit sets, reps, and RIR for any specific week, with an "apply forward" option.
- **Rich visualizations** — Track your progress via a high-density calendar and a horizontal timeline of your meso.
- **Meso switcher** — Manage multiple mesocycles with historical tracking.
- **Aesthetic design** — Clean dark mode and an Olympic-plate group color system for visual clarity.

## Stack

- **Framework**: Flutter 3.19+
- **Database**: Drift (SQLite) for local-first persistence.
- **State Management**: Riverpod for reactive updates.
- **Typography**: Inter Tight, Archivo, and JetBrains Mono (via google_fonts).

## Setup

Ensure you have Flutter installed, then run:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Schema Layering Rule

Strength Guru uses a layered approach to program overrides via the `DayOverrides` table:

| Scope            | Action                                                               |
| ---------------- | -------------------------------------------------------------------- |
| **Session Swap** | Writes an override for a specific `(weekIdx, dayIdx)`.               |
| **Forward Swap** | Writes overrides for all weeks from `currentWeek` to the end.        |
| **Program Edit** | Writes overrides starting from `week 0` through the end of the meso. |

*Note: Program edits will overwrite any existing per-week swaps for that day to maintain consistency.*

## Project Structure

- `lib/db/`: Database schema (Drift) and seed data.
- `lib/providers/`: Riverpod providers and business logic.
- `lib/screens/`: Main application views (Today, Log, Meso).
- `lib/widgets/`: Reusable UI components.
- `lib/theme/`: Design tokens, atoms, and color systems.
