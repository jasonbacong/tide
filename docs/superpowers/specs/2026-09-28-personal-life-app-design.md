# Personal life app — v1 design

**Date:** 2026-09-28
**Working name:** Tide (easy to rename later)
**Platform:** Android phone (Samsung) first. Flutter, so macOS can follow from the same codebase.

---

## 1. Purpose

A calm, personal "today" space that adds a little routine and simplicity to everyday life and is genuinely pleasant to open.

**Success looks like:**
- Opening the app in the morning takes seconds and shows only what matters today.
- Capturing a thought takes one tap and a sentence.
- It never nags, shouts, or scores. There are no streak counters, percentages, charts, or notifications.
- It feels smooth and calm: soft colours, well-separated sections, gentle motion.

**Explicitly out of scope for v1:** sync, the Mac app, notifications, countdowns, Projects, Life Vault, Finance, Skills, and Annual Review. These are candidates for later versions.

---

## 2. Screens and navigation

A slim bottom bar with three destinations, plus a floating capture button centred above it on every screen.

### 2.1 Today (home)
Top to bottom:
1. **Greeting.** "Good morning / afternoon / evening, {name}", plus the date. Tapping the name opens Settings.
2. **Daily note.** One line in serif italic (see §4.6).
3. **Intention card** (before 17:00) **or Reflection card** (from 17:00). See §4.4.
4. **Habits card.** Circular habit buttons (see §4.3).
5. **Tasks card.** Today's tasks, with filter chips and a "Later" link (see §4.2).
6. **Inbox line.** Shown only when unsorted captures exist, e.g. "3 thoughts in your inbox". It opens the Inbox screen.

### 2.2 Goals
Active goals (maximum 5) as cards, each with a soft progress ring. A collapsed "Past goals" section holds achieved and let-go goals. Tapping a card opens Goal detail.

### 2.3 Journal
- A month mood-dot calendar at the top. Each day shows a small dot in its mood colour; days with no check-in show nothing.
- Below it, a reverse-chronological scroll of past check-ins (intention, mood, reflection).
- Tapping a calendar day scrolls to that entry.

### 2.4 Secondary screens
Reached from the main screens, not the bottom bar:
- **Inbox** (from Today).
- **Later** tasks (from the Tasks card).
- **Goal detail** (from Goals).
- **Settings** (from the greeting).

### 2.5 Capture sheet
Opened by the floating + button on any screen.
- A bottom sheet with a single text field. The keyboard opens immediately.
- Enter or "Save" stores the capture in the Inbox and closes the sheet.
- The + icon rotates into an × while the sheet is open.

### 2.6 First launch
One short welcome screen:
- Asks for a first name.
- Offers three suggested habits to toggle on: Read, Drink water (target 8), and Move. You can skip them.
- Then lands on Today.

---

## 3. Visual design

### 3.1 Palette: "Sand and sea"

| Token | Light | Dark |
|---|---|---|
| background | `#F6EFE6` | `#1F1C19` |
| card | `#FFFFFF` | `#2A2622` |
| ink (primary text) | `#3A332C` | `#EFE7DC` |
| muted (secondary text) | `#8A7F72` | `#A89C8E` |
| accent (sea) | `#6FA3A0` | `#7FB5B1` |
| warm (terracotta) | `#D08A6A` | `#DB9B7C` |
| soft (empty ring / track) | `#E6DED2` | `#3A342E` |

**Mood scale (5 levels, low → high):** `#B7A6C9`, `#9DB4CF`, `#C9C2B4`, `#E3C27E`, `#E59A77`. The same values are used in both modes.

**Theme:** follows system light/dark by default and can be overridden in Settings.

### 3.2 Time-of-day tint
The background blends slightly toward a tint depending on the time of day, at most 6% strength:

| Period | Hours | Tint |
|---|---|---|
| Morning | 05:00–11:59 | lighter, cooler |
| Afternoon | 12:00–16:59 | neutral |
| Evening | 17:00–21:59 | warmer |
| Night | 22:00–04:59 | deeper |

The tint is recalculated when the app resumes and on the hour while it is open. It cross-fades over 600 ms.

### 3.3 Typography
Fonts are bundled so they work offline.
- **Fraunces** (serif) for the greeting and daily note.
- **Inter** (sans-serif) for everything else.
- Only two weights are used: regular and medium.

### 3.4 Layout
- Cards: 18 px corner radius, 16 px padding, 12 px gap between cards, 16 px screen margins.
- No divider lines and no shadows. Separation comes from spacing and card colour alone.

### 3.5 Motion
All motion uses soft ease-out curves with no overshoot or bounce.

| Interaction | Behaviour |
|---|---|
| Screen and card entry | Fade in and rise 8 px over ~250 ms, staggered 60 ms per card. |
| Habit tap | The ring fills by one segment (~600 ms). When the target is reached, the inner circle blooms to full (~500 ms) and one ripple expands and fades (~900 ms). A light haptic tap fires on every tap; a medium tap fires on completion. |
| Task complete | The circle fills (350 ms), then the strikethrough draws across (400 ms), then the row slides to the bottom of the list (450 ms). A light haptic tap. |
| Capture sheet | Glides up in ~380 ms. The + button rotates 45°. |
| Undo snackbar | Fades in and stays for 4 s. |

When Android's "remove animations" setting is on (`MediaQuery.disableAnimations`), all durations drop to 0. Haptics are kept.

---

## 4. Features and behaviour

### 4.1 Captures and Inbox
- A capture is free text. It is created with status `inbox`.
- The Inbox lists captures oldest first. Each has three actions:
  - **Make task:** opens the task editor with the text prefilled. On save, the capture's status becomes `converted`.
  - **Link to goal:** makes a task linked to the chosen goal. The capture becomes `converted`.
  - **Archive:** the capture's status becomes `archived`.
- Swiping a capture left archives it, with Undo.

### 4.2 Tasks
**Fields:**
- `title` (required)
- `energy`: low, medium, high, or none
- `minutes`: 5, 15, 30, 60 (shown as "60+"), or none
- `date`: a date, or none, meaning "Later"
- `goalId`: optional
- `completedAt`

**Which tasks appear on Today:**
- Open tasks with `date ≤ today`.
- Plus tasks completed today, shown faded and below the open ones.

**Behaviour:**
- **Roll forward:** open tasks with a past date simply keep showing on Today. There are no overdue labels and no red.
- **Later:** a list of tasks with no date. You can move a task to Today, or set a date.
- **Filter chips on the Tasks card:** energy (Low / Med / High) and time (≤15 min / ≤30 min). Choosing more than one filter narrows the list. The filter resets each day.
- **Add a task:** a small "+ Add task" row at the bottom of the card opens the task editor, with the date defaulting to today.
- **Reorder:** long-press and drag within Today.
- **Delete:** swipe left, with Undo.

### 4.3 Habits
**Fields:**
- `name`
- `icon`, from a curated set of about 24 outline icons
- `dailyTarget` (default 1)
- `goalId`: optional
- `archived`
- `sortOrder`

**How ticking works:**
- Each tap on a habit increments today's count, up to the target.
- Tapping a completed habit resets today's count to 0, so mistakes are easy to undo.
- For habits with a target above 1, the ring shows target-many segments.
- A caption under the row briefly shows e.g. "Water 3 of 8".

**Daily reset:** counts are stored per date in `HabitTick`, so each new day starts at 0 automatically. When the app resumes, and on a timer at local midnight while it is open, "today" is recalculated and the screen rebuilds.

**Limits:** a soft maximum of 8 active habits. Settings explains why ("keep it light") rather than blocking outright past 8.

**History:** long-press a habit to open a small sheet with a 5-week dot grid of the days it was completed. There are no numbers and no streaks.

**Linked goal:** if a habit is linked to a goal, its long-press sheet shows "→ {goal title}".

### 4.4 Check-in
There is one `CheckIn` record per date. The intention, mood and reflection are all optional.
- **Intention card** (before 17:00): "What would make today good?" A single line. Once saved, it shows as quiet text; tap to edit.
- **Reflection card** (from 17:00):
  - Shows the morning intention, if one exists.
  - Five mood circles in the mood palette.
  - A multi-line "How was today?" field.
- **Saving:** changes save automatically after typing stops (debounce of 600 ms). The card shows a subtle "Saved".
- **Past days:** can be edited from the Journal.

### 4.5 Goals
**Fields:**
- `title`
- `why` (short text)
- `targetSeason`: optional free text, e.g. "by spring"
- `status`: active, achieved, or let go
- `completedAt`

**Milestones:** each goal has an ordered list of milestones (title and a done flag).

**Progress ring:** milestones done ÷ total milestones. If a goal has no milestones, no ring is shown.

**Goal detail screen:**
- Why, season and milestones. Tapping a milestone toggles it; long-press and drag to reorder.
- Linked habits and tasks. Linked items show a quiet "→ {goal}" line wherever they appear.
- "Mark achieved" plays a gentle bloom on the ring and moves the goal to Past goals.
- "Let it go" moves the goal to Past goals without ceremony.

**Limit:** at most 5 active goals. Adding a sixth shows: "You have 5 goals already. Finish or let one go first."

### 4.6 Daily note
Chosen once per local date, then fixed for the rest of that day.

1. **Resurfaced reflection.** If a non-empty reflection exists from 30, 90 or 365 days ago (checked in that order, each ±2 days), show "A month ago you wrote: …", "Three months ago…" or "A year ago…". Long text is truncated to about 100 characters.
2. **Otherwise, a built-in line.** Pick a line from a bundled set of about 60 original short lines and gentle prompts written for the app. No third-party quotes are used. The choice is seeded by date, so it's stable within the day and varies across days.

### 4.7 Settings
- **Name.**
- **Habits:** add, edit, reorder, archive.
- **Theme:** system, light, or dark.
- **Backup:** Export, Import, list of automatic backups with a Restore option, and a "Last exported" date.
- **About.**

---

## 5. Architecture

### 5.1 Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (stable), Dart |
| Minimum Android version | 8.0 (API 26) |
| Local database | `drift` (SQLite), with versioned migrations |
| State management | `flutter_riverpod` |
| Navigation | `go_router`, with a `StatefulShellRoute` for the three tabs |
| Haptics | Flutter's built-in `HapticFeedback` |
| Backup file access | `path_provider`, `file_picker`, `share_plus` |
| IDs | `uuid` (v4) |

### 5.2 Project layout
The Flutter project sits at the repo root.

```
lib/
  main.dart
  app.dart                 # MaterialApp.router, theme, router
  ui/                      # theme tokens, time-of-day tint, shared widgets (Card, Ring, Chip, Bloom)
  data/
    db/                    # drift tables, database, migrations
    repositories/          # one repository per feature; the only code that touches drift
    clock.dart             # injectable "now" and "today", used everywhere, for testability
  features/
    today/  capture/  tasks/  habits/  checkin/  goals/  journal/  settings/  onboarding/
      (each: screens/, widgets/, providers.dart)
  content/
    daily_lines.dart       # bundled daily-note lines
test/
  unit/  widget/
```

### 5.3 Boundaries
- **Screens and widgets** read only from Riverpod providers. They never touch drift directly.
- **Providers** expose repository streams and actions.
- **Repositories** own all queries and writes, and return plain domain objects, not drift rows.
- **`Clock`** is the only source of the current time and "today", so date logic can be tested by faking it.

### 5.4 Data model
Every table has `id` (UUID text primary key), `createdAt`, `updatedAt` and `deletedAt` (nullable). `deletedAt` is a tombstone that supports Undo now and sync later. Dates are stored as local ISO `yyyy-MM-dd` strings; timestamps are stored in UTC.

| Table | Columns (in addition to the common ones) |
|---|---|
| `captures` | `text`, `status` (inbox / converted / archived) |
| `tasks` | `title`, `energy?`, `minutes?`, `date?`, `goalId?`, `completedAt?`, `sortOrder` |
| `habits` | `name`, `icon`, `dailyTarget`, `goalId?`, `archived`, `sortOrder` |
| `habit_ticks` | `habitId`, `date`, `count`. Unique on (`habitId`, `date`). |
| `check_ins` | `date` (unique), `intention?`, `mood?` (1–5), `reflection?` |
| `goals` | `title`, `why?`, `targetSeason?`, `status`, `completedAt?`, `sortOrder` |
| `milestones` | `goalId`, `title`, `done`, `sortOrder` |
| `settings` | a single row: `name`, `themeMode`, `lastExportAt?`, `lastAutoBackupAt?` |

**How deletes work:**
- A deletion sets `deletedAt`. All queries exclude rows where `deletedAt` is set.
- Rows that have been tombstoned for more than 30 days are purged on app start.
- Deleting a goal clears `goalId` on any linked tasks and habits.

---

## 6. Data safety

- **Automatic backup:** on app start, if the last automatic backup is 7 or more days old, the app writes a full JSON export to app storage. It keeps the newest 4.
  - Settings states plainly that these backups are lost if the app is uninstalled, which is why Export exists.
- **Export:** writes a single JSON file containing all tables plus a `schemaVersion`, then opens Android's share/save sheet so you can send it to Drive, email, and so on. It updates `lastExportAt`.
  - Settings shows a quiet "Last exported 40 days ago" line. There are no notifications.
- **Import / Restore:**
  - Validates `schemaVersion` and structure before touching anything.
  - Shows a confirm dialog: "This replaces everything in the app."
  - Takes an automatic backup of the current data first.
  - Replaces all data inside a single transaction, so a failed import leaves the existing data untouched.
- **Migrations:** before running a schema migration, the app copies the database file to a `pre-migration-v{N}` backup.
- **Database open failure:** the app shows a calm screen offering "Restore latest backup" or "Import a file". It never silently starts blank.
- **Error messages:** no raw exceptions are shown. You see short messages such as "Couldn't save that. Try again", and whatever you typed stays in its field.

---

## 7. Testing

**Unit tests**, using a fake `Clock` and an in-memory drift database:
- The day rollover changes "today" and gives habits fresh counts.
- Tasks roll forward and the Today query is correct (including completed-today).
- Habit tick increment and reset, including the target cap.
- The goal ring calculation, including goals with no milestones.
- The 5-goal limit.
- Daily note selection: the resurfacing windows, their order, the ±2 day tolerance, the fallback, and the same result within a day.
- Export → import produces identical data.
- Import rejects a malformed file without changing data.
- Tombstone purge after 30 days.

**Widget tests:**
- Capture from Today lands in the Inbox.
- Ticking a habit to its target shows the completed state.
- Completing a task moves it below the open tasks.
- Intention and reflection auto-save.
- The time-of-day switch shows the Reflection card at 17:00.

**Device checks:** at each milestone, install on the Samsung and check feel, speed and haptics.

---

## 8. Delivery milestones

1. **Foundation:** Flutter and Android toolchain installed; project, theme, fonts, database, `Clock`, three-tab navigation, and the capture sheet with Inbox.
2. **Today core:** tasks (including Later and filters) and habits (including ticks and history).
3. **Reflection:** the check-in cards, the Journal with the mood calendar, and the daily note.
4. **Goals:** goals, milestones, linking, and the progress ring.
5. **Safety and polish:** settings, onboarding, export/import, automatic backups, a motion pass, and a release APK installed on the phone.
