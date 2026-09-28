# Tide — Milestone 1 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Tide app that installs on Jason's Samsung and has these working parts:
- the Sand and sea theme, with a background tint that follows the time of day;
- a greeting and date header;
- three-tab navigation (Today, Goals, Journal);
- a floating capture button that saves thoughts into an Inbox, where they can be archived with Undo.

**Architecture:** A Flutter app at the repo root. The layers are:
- **drift (SQLite):** holds the full v1 schema.
- **Repositories:** the only code that touches drift. They return plain domain objects.
- **Riverpod providers:** expose those repositories to the UI.
- **go_router:** a `StatefulShellRoute` provides the three tabs.
- **`Clock`:** the single source of "now", so date and time logic can be tested.

**Tech Stack:** Flutter (stable) and Dart 3, flutter_riverpod, go_router, drift + drift_flutter (with drift_dev and build_runner for code generation), uuid, intl.

**Spec:** `docs/superpowers/specs/2026-09-28-personal-life-app-design.md`

**Later milestones:** M2 (Today core), M3 (Reflection), M4 (Goals) and M5 (Safety and polish) each get their own plan, written after the previous milestone ships.

## Global Constraints

- Android minimum SDK is **26** (Android 8.0).
- Package name is `tide`. The Android application ID is `com.jasongrech.tide`. The app label is `Tide`.
- Palette values are exactly as listed in spec §3.1. Light: background `#F6EFE6`, card `#FFFFFF`, ink `#3A332C`, muted `#8A7F72`, accent `#6FA3A0`, warm `#D08A6A`, soft `#E6DED2`. Dark: `#1F1C19`, `#2A2622`, `#EFE7DC`, `#A89C8E`, `#7FB5B1`, `#DB9B7C`, `#3A342E`.
- Time-of-day periods: morning 05:00–11:59, afternoon 12:00–16:59, evening 17:00–21:59, night 22:00–04:59. The tint strength is at most 6%.
- Fonts are bundled: Fraunces (serif, for the greeting and note) and Inter (everything else). Only two weights are used: 400 and 500.
- Motion uses ease-out curves with no overshoot. When `MediaQuery.disableAnimationsOf(context)` is true, every duration becomes 0.
- Every synced table has `id` (UUID text primary key), `createdAt`, `updatedAt` and `deletedAt?`. Dates are `yyyy-MM-dd` local strings. DateTimes are stored as ISO text.
- Screens never touch drift directly. They go through a provider, which goes through a repository.
- All "now" comes from `Clock`. Never call `DateTime.now()` outside `SystemClock`.
- UI copy is sentence case, calm, and never shows raw exceptions. It never uses "successfully" or exclamation marks.
- Never commit personal data. `.gitignore` excludes `*.tide.json` and `backups/`.
- After every commit, run `git push` (remote: `github.com/jasonbacong/tide`, branch `main`).

## Review Focus

1. **Whitespace-only or empty capture.** Nothing is saved and the sheet shows "Type something first". Covered in Task 6 (repository) and Task 8 (sheet).
2. **Double-tapping Save quickly.** Exactly one capture is stored. Covered in Task 8.
3. **Very long (5,000+ character) or emoji / non-Latin captures.** These are stored byte-exact, and the Inbox tile truncates at 4 lines. Covered in Task 6 (round-trip) and Task 9 (truncation).
4. **App left open across midnight, or resumed the next morning.** The date, greeting and tint update. Covered in Task 3 (period boundaries) and Task 7 (`NowNotifier.refresh`).
5. **Archiving the last Inbox item, then tapping Undo.** The empty state appears, then the item comes back. Covered in Task 9.

---

## File map

```
.gitignore                          # + personal-data exclusions
README.md
build.yaml                          # drift: store DateTimes as text
pubspec.yaml                        # deps + fonts
android/app/build.gradle.kts        # minSdk 26
android/app/src/main/AndroidManifest.xml   # label "Tide"
assets/fonts/{Inter.ttf, Fraunces.ttf, Fraunces-Italic.ttf, OFL-Inter.txt, OFL-Fraunces.txt}
lib/
  main.dart                         # ProviderScope + TideApp
  app.dart                          # TideApp: MaterialApp.router, theme, lifecycle → now refresh
  router.dart                       # buildRouter(), calmPage()
  data/
    clock.dart                      # Clock, SystemClock, dateKey()
    enums.dart                      # CaptureStatus, Energy, GoalStatus, ThemePreference
    providers.dart                  # databaseProvider, clockProvider, captureRepositoryProvider, nowProvider, dayPeriodProvider
    db/tables.dart                  # all drift tables
    db/app_database.dart            # AppDatabase (+ generated app_database.g.dart)
    repositories/capture_repository.dart   # Capture, CaptureRepository
  ui/
    day_period.dart                 # DayPeriod, periodFor(), tintedBackground()
    tide_colors.dart                # TideColors ThemeExtension, context.tide
    typography.dart                 # TideType
    motion.dart                     # Motion tokens, motion()
    theme.dart                      # buildTheme()
    home_shell.dart                 # Scaffold + NavigationBar + CaptureButton
  features/
    today/greeting.dart             # greetingFor()
    today/today_header.dart
    today/today_screen.dart
    today/inbox_line.dart           # inboxLabel(), InboxLine
    goals/goals_screen.dart
    journal/journal_screen.dart
    capture/capture_sheet.dart      # showCaptureSheet(), CaptureSheet
    capture/capture_button.dart
    capture/providers.dart          # inboxProvider, inboxCountProvider
    capture/inbox_screen.dart
test/
  support/fake_clock.dart  support/test_db.dart  support/pump_app.dart
  unit/clock_test.dart  unit/day_period_test.dart  unit/greeting_test.dart  unit/theme_test.dart
  unit/app_database_test.dart  unit/capture_repository_test.dart  unit/now_provider_test.dart
  widget/motion_test.dart  widget/shell_test.dart  widget/capture_test.dart  widget/inbox_test.dart
```

---

### Task 1: Toolchain and project scaffold

**Files:**
- Create: the Flutter project at the repo root (generated), `README.md`, `test/widget/app_smoke_test.dart`
- Modify: `.gitignore`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`
- Delete: `test/widget_test.dart` (generated)

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable Flutter project named `tide` with its dependencies installed. The `flutter test` and `flutter analyze` commands are green.

- [ ] **Step 1: Install the Flutter SDK**

```bash
brew install --cask flutter
flutter --version
```

Expected: this prints `Flutter 3.x.x • channel stable`.

- [ ] **Step 2: Point Flutter at the existing JDK 21**

```bash
flutter config --jdk-dir "$(/usr/libexec/java_home -v 21)"
```

Expected: `Setting "jdk-dir" value to ".../jbr-21.0.11/Contents/Home"`.

- [ ] **Step 3: Install the Android command-line tools and tell Flutter where they are**

```bash
brew install --cask android-commandlinetools
flutter config --android-sdk "$(brew --prefix)/share/android-commandlinetools"
```

- [ ] **Step 4: USER STEP — Jason accepts the Android SDK licences**

Accepting licence agreements is Jason's decision. The agent must not pipe `yes` into this command. Ask Jason to run it in his own terminal, read the licences, and accept them:

```bash
flutter doctor --android-licenses
```

Wait until Jason confirms he has done this.

- [ ] **Step 5: Install the platform tools and verify**

```bash
"$(brew --prefix)/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager" "platform-tools"
flutter doctor
```

Expected: `[✓] Flutter` and `[✓] Android toolchain`. Warnings for Xcode, Chrome or Android Studio are fine and can be ignored. The Gradle build downloads any missing platforms and build tools automatically on the first build.

- [ ] **Step 6: Create the project in the repo root**

Run from the repo root, `/Users/jasongrech/Documents/01. SITES/PERSONAL`:

```bash
flutter create --org com.jasongrech --project-name tide --platforms android .
rm test/widget_test.dart
flutter pub add flutter_riverpod go_router drift drift_flutter uuid intl
flutter pub add dev:drift_dev dev:build_runner
```

- [ ] **Step 7: Set minSdk and the app label**

In `android/app/build.gradle.kts`, inside `defaultConfig { ... }`, change the `minSdk` line to:

```kotlin
        minSdk = 26
```

In `android/app/src/main/AndroidManifest.xml`, change `android:label="tide"` to:

```xml
        android:label="Tide"
```

- [ ] **Step 8: Add personal-data exclusions to `.gitignore` and add a README**

Append to `.gitignore`:

```gitignore

# Tide: never commit personal data
*.tide.json
backups/
```

Create `README.md`:

```markdown
# Tide

A calm personal "today" app: quick capture, tasks, habits, check-ins and goals. Flutter, Android first.

- Design: `docs/superpowers/specs/2026-09-28-personal-life-app-design.md`
- Plans: `docs/superpowers/plans/`

Run tests: `flutter test` · Run on phone: `flutter run`
```

- [ ] **Step 9: Write the smoke test**

Create `test/widget/app_smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const PlaceholderApp());
    expect(find.text('Tide'), findsOneWidget);
  });
}
```

- [ ] **Step 10: Run the test and confirm it fails**

Run: `flutter test test/widget/app_smoke_test.dart`
Expected: FAIL, because `PlaceholderApp` isn't defined.

- [ ] **Step 11: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';

void main() => runApp(const PlaceholderApp());

class PlaceholderApp extends StatelessWidget {
  const PlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Center(child: Text('Tide'))));
}
```

- [ ] **Step 12: Run the tests and analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 13: Commit and push**

```bash
git add -A
git commit -m "chore: scaffold Flutter project for Android"
git push
```

---

### Task 2: Clock and date keys

**Files:**
- Create: `lib/data/clock.dart`, `test/support/fake_clock.dart`, `test/unit/clock_test.dart`

**Interfaces:**
- Produces:
  - `abstract class Clock { DateTime now(); }`
  - `class SystemClock implements Clock` (const constructor)
  - `String dateKey(DateTime local)`, which returns `yyyy-MM-dd`
  - For tests only: `class FakeClock implements Clock { FakeClock(DateTime); void set(DateTime); void advance(Duration); }`

- [ ] **Step 1: Create the test fake**

`test/support/fake_clock.dart`:

```dart
import 'package:tide/data/clock.dart';

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;
  void advance(Duration by) => _now = _now.add(by);
}
```

- [ ] **Step 2: Write the failing test**

`test/unit/clock_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/clock.dart';

import '../support/fake_clock.dart';

void main() {
  test('dateKey pads month and day', () {
    expect(dateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('dateKey uses the local calendar date', () {
    expect(dateKey(DateTime(2026, 12, 31, 0, 0)), '2026-12-31');
  });

  test('FakeClock advances', () {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 30));
    clock.advance(const Duration(hours: 1));
    expect(dateKey(clock.now()), '2026-09-29');
  });

  test('SystemClock returns a current time', () {
    final before = DateTime.now();
    final now = const SystemClock().now();
    expect(now.isBefore(before), isFalse);
  });
}
```

- [ ] **Step 3: Run the test and confirm it fails**

Run: `flutter test test/unit/clock_test.dart`
Expected: FAIL, because `package:tide/data/clock.dart` is not found.

- [ ] **Step 4: Implement**

`lib/data/clock.dart`:

```dart
/// The only source of "now" in the app. Inject a fake in tests.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Local calendar date as `yyyy-MM-dd`, used as the key for per-day records.
String dateKey(DateTime local) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
}
```

- [ ] **Step 5: Run the test and confirm it passes**

Run: `flutter test test/unit/clock_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/data/clock.dart test/support/fake_clock.dart test/unit/clock_test.dart
git commit -m "feat: add injectable clock and date keys"
git push
```

---

### Task 3: Day periods, background tint and greeting

**Files:**
- Create: `lib/ui/day_period.dart`, `lib/features/today/greeting.dart`, `test/unit/day_period_test.dart`, `test/unit/greeting_test.dart`

**Interfaces:**
- Produces:
  - `enum DayPeriod { morning, afternoon, evening, night }`
  - `DayPeriod periodFor(DateTime local)`
  - `Color tintedBackground(Color base, DayPeriod period, Brightness brightness)`
  - `String greetingFor(DayPeriod period, String name)`

- [ ] **Step 1: Write the failing tests**

`test/unit/day_period_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/day_period.dart';

void main() {
  group('periodFor boundaries', () {
    final cases = <(int, int, DayPeriod)>[
      (4, 59, DayPeriod.night),
      (5, 0, DayPeriod.morning),
      (11, 59, DayPeriod.morning),
      (12, 0, DayPeriod.afternoon),
      (16, 59, DayPeriod.afternoon),
      (17, 0, DayPeriod.evening),
      (21, 59, DayPeriod.evening),
      (22, 0, DayPeriod.night),
      (0, 0, DayPeriod.night),
    ];
    for (final (h, m, expected) in cases) {
      test('$h:$m is $expected', () {
        expect(periodFor(DateTime(2026, 9, 28, h, m)), expected);
      });
    }
  });

  group('tintedBackground', () {
    const base = Color(0xFFF6EFE6);

    test('afternoon leaves the background untouched', () {
      expect(tintedBackground(base, DayPeriod.afternoon, Brightness.light), base);
    });

    for (final period in [DayPeriod.morning, DayPeriod.evening, DayPeriod.night]) {
      for (final b in Brightness.values) {
        test('$period/$b shifts gently (<= 6% per channel)', () {
          final tinted = tintedBackground(base, period, b);
          expect(tinted, isNot(base));
          for (final (x, y) in [(tinted.r, base.r), (tinted.g, base.g), (tinted.b, base.b)]) {
            expect((x - y).abs(), lessThanOrEqualTo(0.06 + 1e-9));
          }
        });
      }
    }
  });
}
```

`test/unit/greeting_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/today/greeting.dart';
import 'package:tide/ui/day_period.dart';

void main() {
  test('greets by period with a name', () {
    expect(greetingFor(DayPeriod.morning, 'Jason'), 'Good morning, Jason');
    expect(greetingFor(DayPeriod.afternoon, 'Jason'), 'Good afternoon, Jason');
    expect(greetingFor(DayPeriod.evening, 'Jason'), 'Good evening, Jason');
    expect(greetingFor(DayPeriod.night, 'Jason'), 'Good evening, Jason');
  });

  test('drops the comma when no name is set', () {
    expect(greetingFor(DayPeriod.morning, ''), 'Good morning');
    expect(greetingFor(DayPeriod.morning, '   '), 'Good morning');
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/unit/day_period_test.dart test/unit/greeting_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 3: Implement**

`lib/ui/day_period.dart`:

```dart
import 'package:flutter/painting.dart';

enum DayPeriod { morning, afternoon, evening, night }

DayPeriod periodFor(DateTime local) {
  final h = local.hour;
  if (h >= 5 && h < 12) return DayPeriod.morning;
  if (h >= 12 && h < 17) return DayPeriod.afternoon;
  if (h >= 17 && h < 22) return DayPeriod.evening;
  return DayPeriod.night;
}

const _tintStrength = 0.06;

/// Blends the base background a few percent toward a mood for the time of day.
Color tintedBackground(Color base, DayPeriod period, Brightness brightness) {
  final tint = switch ((period, brightness)) {
    (DayPeriod.afternoon, _) => null,
    (DayPeriod.morning, Brightness.light) => const Color(0xFFE6F2F4),
    (DayPeriod.morning, Brightness.dark) => const Color(0xFF3B4C52),
    (DayPeriod.evening, Brightness.light) => const Color(0xFFF3C6A5),
    (DayPeriod.evening, Brightness.dark) => const Color(0xFF5C3F2E),
    (DayPeriod.night, Brightness.light) => const Color(0xFF9FA8B8),
    (DayPeriod.night, Brightness.dark) => const Color(0xFF0D1117),
  };
  return tint == null ? base : Color.lerp(base, tint, _tintStrength)!;
}
```

`lib/features/today/greeting.dart`:

```dart
import '../../ui/day_period.dart';

String greetingFor(DayPeriod period, String name) {
  final hello = switch (period) {
    DayPeriod.morning => 'Good morning',
    DayPeriod.afternoon => 'Good afternoon',
    DayPeriod.evening || DayPeriod.night => 'Good evening',
  };
  final trimmed = name.trim();
  return trimmed.isEmpty ? hello : '$hello, $trimmed';
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/unit/day_period_test.dart test/unit/greeting_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit and push**

```bash
git add lib/ui/day_period.dart lib/features/today/greeting.dart test/unit/day_period_test.dart test/unit/greeting_test.dart
git commit -m "feat: add day periods, background tint and greeting"
git push
```

---

### Task 4: Theme — colours, fonts, typography and motion

**Files:**
- Create: `assets/fonts/*`, `lib/ui/tide_colors.dart`, `lib/ui/typography.dart`, `lib/ui/motion.dart`, `lib/ui/theme.dart`, `test/unit/theme_test.dart`, `test/widget/motion_test.dart`
- Modify: `pubspec.yaml` (the `flutter:` section)

**Interfaces:**
- Consumes: `DayPeriod` and `tintedBackground` from Task 3.
- Produces:
  - `class TideColors extends ThemeExtension<TideColors>`
    - fields: `background, card, ink, muted, accent, warm, soft`
    - statics: `light`, `dark`, `mood` (a `List<Color>` of 5)
  - `extension TideColorsX on BuildContext { TideColors get tide; }`
  - `abstract final class TideType`
    - constants: `sans`, `serif`
    - style builders (each takes a `Color` and returns a `TextStyle`): `greeting`, `note`, `title`, `body`, `label`
  - `abstract final class Motion`
    - durations: `quick`, `stagger`, `sheet`, `crossfade`, `ringFill`, `bloom`, `ripple`, `taskCheck`, `strike`, `settle`
    - curve: `ease`
  - `Duration motion(BuildContext, Duration)`
  - `ThemeData buildTheme(Brightness, DayPeriod)`

- [ ] **Step 1: Download the fonts (SIL Open Font License, from the official google/fonts repository)**

```bash
mkdir -p assets/fonts
curl -fL -o assets/fonts/Inter.ttf "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
curl -fL -o assets/fonts/Fraunces.ttf "https://github.com/google/fonts/raw/main/ofl/fraunces/Fraunces%5BSOFT,WONK,opsz,wght%5D.ttf"
curl -fL -o assets/fonts/Fraunces-Italic.ttf "https://github.com/google/fonts/raw/main/ofl/fraunces/Fraunces-Italic%5BSOFT,WONK,opsz,wght%5D.ttf"
curl -fL -o assets/fonts/OFL-Inter.txt "https://github.com/google/fonts/raw/main/ofl/inter/OFL.txt"
curl -fL -o assets/fonts/OFL-Fraunces.txt "https://github.com/google/fonts/raw/main/ofl/fraunces/OFL.txt"
file assets/fonts/*.ttf
```

Expected: each `.ttf` reports `TrueType Font data` and is larger than 100 KB (`ls -l assets/fonts`). If a URL returns 404, open `https://github.com/google/fonts/tree/main/ofl/inter` (or `.../fraunces`) to find the current file name.

- [ ] **Step 2: Register the fonts in `pubspec.yaml`**

Under the existing `flutter:` key, next to `uses-material-design: true`, add:

```yaml
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter.ttf
    - family: Fraunces
      fonts:
        - asset: assets/fonts/Fraunces.ttf
        - asset: assets/fonts/Fraunces-Italic.ttf
          style: italic
```

- [ ] **Step 3: Write the failing tests**

`test/unit/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/tide_colors.dart';

void main() {
  test('light theme uses Sand and sea light tokens', () {
    final theme = buildTheme(Brightness.light, DayPeriod.afternoon);
    final c = theme.extension<TideColors>()!;
    expect(c.accent, const Color(0xFF6FA3A0));
    expect(c.card, const Color(0xFFFFFFFF));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF6EFE6));
  });

  test('dark theme uses Sand and sea dark tokens', () {
    final theme = buildTheme(Brightness.dark, DayPeriod.afternoon);
    final c = theme.extension<TideColors>()!;
    expect(c.accent, const Color(0xFF7FB5B1));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF1F1C19));
  });

  test('evening tints the background but not the cards', () {
    final theme = buildTheme(Brightness.light, DayPeriod.evening);
    expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFF6EFE6)));
    expect(theme.extension<TideColors>()!.card, const Color(0xFFFFFFFF));
    expect(theme.extension<TideColors>()!.background, theme.scaffoldBackgroundColor);
  });

  test('body text uses Inter', () {
    final theme = buildTheme(Brightness.light, DayPeriod.morning);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  test('mood scale has five colours', () {
    expect(TideColors.mood, hasLength(5));
  });
}
```

`test/widget/motion_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/motion.dart';

void main() {
  Future<Duration> resolve(WidgetTester tester, {required bool reduce}) async {
    late Duration result;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Builder(builder: (context) {
        result = motion(context, Motion.sheet);
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets('keeps durations normally', (tester) async {
    expect(await resolve(tester, reduce: false), Motion.sheet);
  });

  testWidgets('drops durations to zero when animations are disabled', (tester) async {
    expect(await resolve(tester, reduce: true), Duration.zero);
  });
}
```

- [ ] **Step 4: Run the tests and confirm they fail**

Run: `flutter test test/unit/theme_test.dart test/widget/motion_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 5: Implement `lib/ui/tide_colors.dart`**

```dart
import 'package:flutter/material.dart';

@immutable
class TideColors extends ThemeExtension<TideColors> {
  const TideColors({
    required this.background,
    required this.card,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.warm,
    required this.soft,
  });

  final Color background;
  final Color card;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color warm;
  final Color soft;

  static const light = TideColors(
    background: Color(0xFFF6EFE6),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3A332C),
    muted: Color(0xFF8A7F72),
    accent: Color(0xFF6FA3A0),
    warm: Color(0xFFD08A6A),
    soft: Color(0xFFE6DED2),
  );

  static const dark = TideColors(
    background: Color(0xFF1F1C19),
    card: Color(0xFF2A2622),
    ink: Color(0xFFEFE7DC),
    muted: Color(0xFFA89C8E),
    accent: Color(0xFF7FB5B1),
    warm: Color(0xFFDB9B7C),
    soft: Color(0xFF3A342E),
  );

  /// Mood 1 (low) → 5 (high). Same in both modes.
  static const mood = [
    Color(0xFFB7A6C9),
    Color(0xFF9DB4CF),
    Color(0xFFC9C2B4),
    Color(0xFFE3C27E),
    Color(0xFFE59A77),
  ];

  @override
  TideColors copyWith({
    Color? background,
    Color? card,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? warm,
    Color? soft,
  }) =>
      TideColors(
        background: background ?? this.background,
        card: card ?? this.card,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        warm: warm ?? this.warm,
        soft: soft ?? this.soft,
      );

  @override
  TideColors lerp(ThemeExtension<TideColors>? other, double t) {
    if (other is! TideColors) return this;
    return TideColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}

extension TideColorsX on BuildContext {
  TideColors get tide => Theme.of(this).extension<TideColors>()!;
}
```

- [ ] **Step 6: Implement `lib/ui/typography.dart`**

```dart
import 'dart:ui' show FontVariation;

import 'package:flutter/painting.dart';

/// Fonts are variable, so weight is set through the `wght` axis as well as fontWeight.
abstract final class TideType {
  static const sans = 'Inter';
  static const serif = 'Fraunces';

  static const _regular = [FontVariation('wght', 400)];
  static const _medium = [FontVariation('wght', 500)];
  static const _softSerif = [FontVariation('wght', 400), FontVariation('SOFT', 100)];

  static TextStyle greeting(Color color) => TextStyle(
      fontFamily: serif, fontSize: 28, height: 1.2, color: color, fontVariations: _softSerif);

  static TextStyle note(Color color) => TextStyle(
      fontFamily: serif,
      fontSize: 15,
      height: 1.4,
      fontStyle: FontStyle.italic,
      color: color,
      fontVariations: _softSerif);

  static TextStyle title(Color color) => TextStyle(
      fontFamily: sans,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: color,
      fontVariations: _medium);

  static TextStyle body(Color color) =>
      TextStyle(fontFamily: sans, fontSize: 15, height: 1.45, color: color, fontVariations: _regular);

  static TextStyle label(Color color) => TextStyle(
      fontFamily: sans, fontSize: 12.5, letterSpacing: 0.2, color: color, fontVariations: _regular);
}
```

- [ ] **Step 7: Implement `lib/ui/motion.dart`**

```dart
import 'package:flutter/widgets.dart';

/// Motion tokens from spec §3.5. Soft ease-out, no overshoot.
abstract final class Motion {
  static const quick = Duration(milliseconds: 250);
  static const stagger = Duration(milliseconds: 60);
  static const sheet = Duration(milliseconds: 380);
  static const crossfade = Duration(milliseconds: 600);
  static const ringFill = Duration(milliseconds: 600);
  static const bloom = Duration(milliseconds: 500);
  static const ripple = Duration(milliseconds: 900);
  static const taskCheck = Duration(milliseconds: 350);
  static const strike = Duration(milliseconds: 400);
  static const settle = Duration(milliseconds: 450);
  static const ease = Cubic(0.3, 0.7, 0.2, 1.0);
}

/// Returns [duration], or zero when the system asks for reduced motion.
Duration motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
```

- [ ] **Step 8: Implement `lib/ui/theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'day_period.dart';
import 'tide_colors.dart';
import 'typography.dart';

ThemeData buildTheme(Brightness brightness, DayPeriod period) {
  final base = brightness == Brightness.light ? TideColors.light : TideColors.dark;
  final colors = base.copyWith(
    background: tintedBackground(base.background, period, brightness),
  );
  final scheme = ColorScheme.fromSeed(seedColor: colors.accent, brightness: brightness).copyWith(
    primary: colors.accent,
    onPrimary: Colors.white,
    secondary: colors.warm,
    surface: colors.background,
    onSurface: colors.ink,
  );
  final rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    fontFamily: TideType.sans,
    extensions: [colors],
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.card,
      indicatorColor: colors.soft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.ink,
      contentTextStyle: TextStyle(color: colors.background, fontFamily: TideType.sans),
      actionTextColor: colors.accent,
      elevation: 0,
      shape: rounded14,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.background,
      hintStyle: TextStyle(color: colors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: rounded14,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
  );
}
```

- [ ] **Step 9: Run the tests and analyzer**

Run: `flutter test test/unit/theme_test.dart test/widget/motion_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 10: Commit and push**

```bash
git add assets pubspec.yaml lib/ui test/unit/theme_test.dart test/widget/motion_test.dart
git commit -m "feat: add Sand and sea theme, fonts, typography and motion tokens"
git push
```

---

### Task 5: Database schema

**Files:**
- Create: `build.yaml`, `lib/data/enums.dart`, `lib/data/db/tables.dart`, `lib/data/db/app_database.dart`, the generated `lib/data/db/app_database.g.dart`, `test/support/test_db.dart`, `test/unit/app_database_test.dart`

**Interfaces:**
- Produces:
  - Enums: `CaptureStatus { inbox, converted, archived }`, `Energy { low, medium, high }`, `GoalStatus { active, achieved, letGo }`, `ThemePreference { system, light, dark }`.
  - `class AppDatabase`, with:
    - constructor `AppDatabase(QueryExecutor)` and `factory AppDatabase.open()`;
    - table getters `captures`, `tasks`, `habits`, `habitTicks`, `checkIns`, `goals`, `milestones`, `appSettings`;
    - row classes `CaptureRow`, `TaskRow`, `HabitRow`, `HabitTickRow`, `CheckInRow`, `GoalRow`, `MilestoneRow`, `SettingsRow`, with matching `*Companion`s.
  - For tests: `AppDatabase testDb()`.
- **Two naming deviations from the spec:**
  - The capture text column is named `body`, because `text` clashes with drift's `text()` builder.
  - The settings table is `AppSettings` (SQL name `app_settings`). It is a single local-only row with integer `id = 1`, so it has no sync columns.

- [ ] **Step 1: Configure drift to store DateTimes as ISO text**

Create `build.yaml`. Text keeps millisecond ordering and makes exports readable.

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          store_date_time_values_as_text: true
```

- [ ] **Step 2: Create the test helper**

`test/support/test_db.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tide/data/db/app_database.dart';

AppDatabase testDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
```

- [ ] **Step 3: Write the failing test**

`test/unit/app_database_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 28, 9);

  setUp(() => db = testDb());
  tearDown(() => db.close());

  test('creates the single settings row on first open', () async {
    final rows = await db.select(db.appSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 1);
    expect(rows.single.name, '');
    expect(rows.single.themeMode, ThemePreference.system);
  });

  test('habit ticks are unique per habit and date', () async {
    HabitTicksCompanion tick(String id) => HabitTicksCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          habitId: 'h1',
          date: '2026-09-28',
          count: 1,
        );
    await db.into(db.habitTicks).insert(tick('a'));
    await expectLater(db.into(db.habitTicks).insert(tick('b')), throwsA(isA<Exception>()));
  });

  test('mood must be between 1 and 5', () async {
    CheckInsCompanion checkIn(String date, int mood) => CheckInsCompanion.insert(
          id: date,
          createdAt: now,
          updatedAt: now,
          date: date,
          mood: Value(mood),
        );
    await db.into(db.checkIns).insert(checkIn('2026-09-28', 5));
    await expectLater(
        db.into(db.checkIns).insert(checkIn('2026-09-29', 6)), throwsA(isA<Exception>()));
  });

  test('stores enums and keeps millisecond timestamps', () async {
    final at = DateTime(2026, 9, 28, 9, 0, 0, 123);
    await db.into(db.goals).insert(GoalsCompanion.insert(
          id: 'g1',
          createdAt: at,
          updatedAt: at,
          title: 'Read 12 books',
          status: GoalStatus.letGo,
        ));
    final row = await db.select(db.goals).getSingle();
    expect(row.status, GoalStatus.letGo);
    expect(row.createdAt.millisecond, 123);
  });
}
```

- [ ] **Step 4: Run the test and confirm it fails**

Run: `flutter test test/unit/app_database_test.dart`
Expected: FAIL, because `app_database.dart` and `enums.dart` are not found.

- [ ] **Step 5: Create `lib/data/enums.dart`**

```dart
enum CaptureStatus { inbox, converted, archived }

enum Energy { low, medium, high }

enum GoalStatus { active, achieved, letGo }

enum ThemePreference { system, light, dark }
```

- [ ] **Step 6: Create `lib/data/db/tables.dart`**

```dart
import 'package:drift/drift.dart';

import '../enums.dart';

/// Columns every synced record carries (spec §5.4).
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CaptureRow')
class Captures extends Table with SyncColumns {
  TextColumn get body => text()();
  TextColumn get status => textEnum<CaptureStatus>()();
}

@DataClassName('TaskRow')
class Tasks extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get energy => textEnum<Energy>().nullable()();
  IntColumn get minutes => integer().nullable()();
  TextColumn get date => text().nullable()();
  TextColumn get goalId => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('HabitRow')
class Habits extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get dailyTarget => integer().withDefault(const Constant(1))();
  TextColumn get goalId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('HabitTickRow')
class HabitTicks extends Table with SyncColumns {
  TextColumn get habitId => text()();
  TextColumn get date => text()();
  IntColumn get count => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {habitId, date},
      ];
}

@DataClassName('CheckInRow')
class CheckIns extends Table with SyncColumns {
  TextColumn get date => text().unique()();
  TextColumn get intention => text().nullable()();
  IntColumn get mood => integer().nullable().check(mood.isBetweenValues(1, 5))();
  TextColumn get reflection => text().nullable()();
}

@DataClassName('GoalRow')
class Goals extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get why => text().nullable()();
  TextColumn get targetSeason => text().nullable()();
  TextColumn get status => textEnum<GoalStatus>()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('MilestoneRow')
class Milestones extends Table with SyncColumns {
  TextColumn get goalId => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Single local-only row (id = 1). Not synced.
@DataClassName('SettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get themeMode =>
      textEnum<ThemePreference>().withDefault(const Constant('system'))();
  DateTimeColumn get lastExportAt => dateTime().nullable()();
  DateTimeColumn get lastAutoBackupAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- [ ] **Step 7: Create `lib/data/db/app_database.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Captures,
  Tasks,
  Habits,
  HabitTicks,
  CheckIns,
  Goals,
  Milestones,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'tide'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(AppSettingsCompanion.insert(id: const Value(1)));
        },
      );
}
```

- [ ] **Step 8: Generate the drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: this ends with `Succeeded after ...` and creates `lib/data/db/app_database.g.dart`.

- [ ] **Step 9: Run the tests and analyzer**

Run: `flutter test test/unit/app_database_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 10: Commit and push**

```bash
git add build.yaml lib/data test/support/test_db.dart test/unit/app_database_test.dart
git commit -m "feat: add v1 drift schema"
git push
```

---

### Task 6: Capture repository

**Files:**
- Create: `lib/data/repositories/capture_repository.dart`, `test/unit/capture_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` and `CaptureStatus` (Task 5), and `Clock` (Task 2).
- Produces:
  - `class Capture { String id; String body; DateTime createdAt; }`
  - `class CaptureRepository`
    - constructor: `CaptureRepository(AppDatabase db, Clock clock, {Uuid uuid})`
    - `Future<Capture?> add(String raw)`: trims the text; returns `null` and writes nothing when the text is blank
    - `Stream<List<Capture>> watchInbox()`: oldest first
    - `Stream<int> watchInboxCount()`
    - `Future<void> archive(String id)`
    - `Future<void> unarchive(String id)`

- [ ] **Step 1: Write the failing test**

`test/unit/capture_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/capture_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late CaptureRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    repo = CaptureRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<List<String>> inboxBodies() async =>
      (await repo.watchInbox().first).map((c) => c.body).toList();

  test('add trims the text and puts it in the inbox', () async {
    final capture = await repo.add('  Call mum  ');
    expect(capture!.body, 'Call mum');
    expect(capture.createdAt, clock.now());
    expect(await inboxBodies(), ['Call mum']);
  });

  test('blank text saves nothing', () async {
    expect(await repo.add(''), isNull);
    expect(await repo.add('   \n  '), isNull);
    expect(await inboxBodies(), isEmpty);
  });

  test('inbox lists oldest first', () async {
    await repo.add('first');
    clock.advance(const Duration(minutes: 1));
    await repo.add('second');
    expect(await inboxBodies(), ['first', 'second']);
  });

  test('archive hides a capture and unarchive brings it back', () async {
    final c = await repo.add('Water the plants');
    await repo.archive(c!.id);
    expect(await inboxBodies(), isEmpty);
    await repo.unarchive(c.id);
    expect(await inboxBodies(), ['Water the plants']);
  });

  test('long, emoji and non-Latin text round-trips exactly', () async {
    final text = ('Plan 🌊 trip — café, 東京, مرحبا. ' * 170).trim();
    expect(text.length, greaterThan(5000));
    await repo.add(text);
    expect(await inboxBodies(), [text]);
  });

  test('inbox count follows the inbox', () async {
    await repo.add('one');
    await repo.add('two');
    expect(await repo.watchInboxCount().first, 2);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/capture_repository_test.dart`
Expected: FAIL, because `capture_repository.dart` is not found.

- [ ] **Step 3: Implement `lib/data/repositories/capture_repository.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../enums.dart';

class Capture {
  const Capture({required this.id, required this.body, required this.createdAt});

  final String id;
  final String body;
  final DateTime createdAt;
}

class CaptureRepository {
  CaptureRepository(this._db, this._clock, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  /// Saves trimmed [raw] to the inbox. Returns null and saves nothing if it is blank.
  Future<Capture?> add(String raw) async {
    final body = raw.trim();
    if (body.isEmpty) return null;
    final now = _clock.now();
    final id = _uuid.v4();
    await _db.into(_db.captures).insert(CapturesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          body: body,
          status: CaptureStatus.inbox,
        ));
    return Capture(id: id, body: body, createdAt: now);
  }

  Stream<List<Capture>> watchInbox() {
    final query = _db.select(_db.captures)
      ..where((c) => c.status.equalsValue(CaptureStatus.inbox) & c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.createdAt),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch().map((rows) => rows.map(_toCapture).toList());
  }

  Stream<int> watchInboxCount() => watchInbox().map((captures) => captures.length);

  Future<void> archive(String id) => _setStatus(id, CaptureStatus.archived);

  Future<void> unarchive(String id) => _setStatus(id, CaptureStatus.inbox);

  Future<void> _setStatus(String id, CaptureStatus status) =>
      (_db.update(_db.captures)..where((c) => c.id.equals(id))).write(
        CapturesCompanion(status: Value(status), updatedAt: Value(_clock.now())),
      );

  static Capture _toCapture(CaptureRow row) =>
      Capture(id: row.id, body: row.body, createdAt: row.createdAt);
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/unit/capture_repository_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit and push**

```bash
git add lib/data/repositories/capture_repository.dart test/unit/capture_repository_test.dart
git commit -m "feat: add capture repository"
git push
```

---

### Task 7: Providers, app shell and Today header

**Files:**
- Create: `lib/data/providers.dart`, `lib/app.dart`, `lib/router.dart`, `lib/ui/home_shell.dart`, `lib/features/today/today_header.dart`, `lib/features/today/today_screen.dart`, `lib/features/goals/goals_screen.dart`, `lib/features/journal/journal_screen.dart`, `test/support/pump_app.dart`, `test/unit/now_provider_test.dart`, `test/widget/shell_test.dart`
- Modify: `lib/main.dart`
- Delete: `test/widget/app_smoke_test.dart`

**Interfaces:**
- Consumes: Tasks 2–6.
- Produces:
  - Providers: `databaseProvider` (`Provider<AppDatabase>`), `clockProvider` (`Provider<Clock>`), `captureRepositoryProvider` (`Provider<CaptureRepository>`), `nowProvider` (`NotifierProvider<NowNotifier, DateTime>`, where `NowNotifier.refresh()` re-reads the clock) and `dayPeriodProvider` (`Provider<DayPeriod>`).
  - Widgets: `TideApp`, `HomeShell({required StatefulNavigationShell shell})`, `TodayScreen`, `GoalsScreen`, `JournalScreen`.
  - Router: `GoRouter buildRouter()` with routes `/today`, `/today/inbox` (added in Task 9), `/goals` and `/journal`, plus `Page<void> calmPage(GoRouterState, Widget)`.
  - Test helpers: `Future<AppDatabase> pumpTideApp(WidgetTester, {FakeClock? clock})` and `Future<void> disposeTideApp(WidgetTester, AppDatabase)`.

- [ ] **Step 1: Write the failing unit test for "now"**

`test/unit/now_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/clock.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/ui/day_period.dart';

import '../support/fake_clock.dart';

void main() {
  test('refresh picks up a new day after midnight', () {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 59));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    addTearDown(container.dispose);

    expect(dateKey(container.read(nowProvider)), '2026-09-28');
    expect(container.read(dayPeriodProvider), DayPeriod.night);

    clock.set(DateTime(2026, 9, 29, 7));
    container.read(nowProvider.notifier).refresh();

    expect(dateKey(container.read(nowProvider)), '2026-09-29');
    expect(container.read(dayPeriodProvider), DayPeriod.morning);
  });
}
```

- [ ] **Step 2: Create the widget-test helper**

`test/support/pump_app.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/app.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';

import 'fake_clock.dart';
import 'test_db.dart';

/// Pumps the full app on an in-memory database. Defaults to Monday 28 Sep 2026, 09:00.
Future<AppDatabase> pumpTideApp(WidgetTester tester, {FakeClock? clock}) async {
  final db = testDb();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock ?? FakeClock(DateTime(2026, 9, 28, 9))),
    ],
    child: const TideApp(),
  ));
  await tester.pumpAndSettle();
  return db;
}

/// Tears the tree down first so providers cancel timers and streams, then closes the DB.
Future<void> disposeTideApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.runAsync(db.close);
}
```

- [ ] **Step 3: Write the failing widget test**

`test/widget/shell_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/goals/goals_screen.dart';
import 'package:tide/features/journal/journal_screen.dart';
import 'package:tide/features/today/today_screen.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('Today shows the date and a morning greeting', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text('Monday, 28 Sep'), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('greeting follows the clock into the evening', (tester) async {
    final db = await pumpTideApp(tester, clock: FakeClock(DateTime(2026, 9, 28, 18)));
    expect(find.text('Good evening'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('bottom bar switches between Today, Goals and Journal', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.byType(TodayScreen), findsOneWidget);

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalsScreen), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.byType(JournalScreen), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 4: Run the tests and confirm they fail**

Run: `flutter test test/unit/now_provider_test.dart test/widget/shell_test.dart`
Expected: FAIL, because `providers.dart`, `app.dart` and the screens are not found.

- [ ] **Step 5: Implement `lib/data/providers.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/day_period.dart';
import 'clock.dart';
import 'db/app_database.dart';
import 'repositories/capture_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Current time, re-read every minute and on app resume (see TideApp).
class NowNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => state = clock.now());
    ref.onDispose(timer.cancel);
    return clock.now();
  }

  void refresh() => state = ref.read(clockProvider).now();
}

final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

final dayPeriodProvider = Provider<DayPeriod>((ref) => periodFor(ref.watch(nowProvider)));
```

- [ ] **Step 6: Implement the screens**

`lib/features/today/today_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'greeting.dart';

class TodayHeader extends ConsumerWidget {
  const TodayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final period = ref.watch(dayPeriodProvider);
    final c = context.tide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE, d MMM').format(now), style: TideType.label(c.muted)),
        const SizedBox(height: 4),
        // Name is wired to settings in Milestone 5 (onboarding).
        Text(greetingFor(period, ''), style: TideType.greeting(c.ink)),
      ],
    );
  }
}
```

`lib/features/today/today_screen.dart`:

```dart
import 'package:flutter/material.dart';

import 'today_header.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: const [
          TodayHeader(),
        ],
      ),
    );
  }
}
```

`lib/features/goals/goals_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Goals', style: TideType.title(c.ink)),
          const SizedBox(height: 8),
          Text('A few things you are working towards will live here.',
              style: TideType.body(c.muted)),
        ],
      ),
    );
  }
}
```

`lib/features/journal/journal_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Journal', style: TideType.title(c.ink)),
          const SizedBox(height: 8),
          Text('Your check-ins will gather here, day by day.', style: TideType.body(c.muted)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Implement the shell, router, app and main**

`lib/ui/home_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goals'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Journal'),
        ],
      ),
    );
  }
}
```

`lib/router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/goals/goals_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/today/today_screen.dart';
import 'ui/home_shell.dart';
import 'ui/motion.dart';

/// Screen entry from spec §3.5: fade in and rise 8 px over ~250 ms.
Page<void> calmPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.quick,
      reverseTransitionDuration: Motion.quick,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(parent: animation, curve: Motion.ease);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.01), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

GoRouter buildRouter() => GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => HomeShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/goals', builder: (context, state) => const GoalsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/journal', builder: (context, state) => const JournalScreen()),
            ]),
          ],
        ),
      ],
    );
```

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'router.dart';
import 'ui/motion.dart';
import 'ui/theme.dart';

class TideApp extends ConsumerStatefulWidget {
  const TideApp({super.key});

  @override
  ConsumerState<TideApp> createState() => _TideAppState();
}

class _TideAppState extends ConsumerState<TideApp> {
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _router = buildRouter();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(nowProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(dayPeriodProvider);
    return MaterialApp.router(
      title: 'Tide',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, period),
      darkTheme: buildTheme(Brightness.dark, period),
      themeMode: ThemeMode.system,
      themeAnimationDuration: Motion.crossfade,
      themeAnimationCurve: Motion.ease,
      routerConfig: _router,
    );
  }
}
```

Replace `lib/main.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TideApp()));
}
```

Then delete the Task 1 smoke test: `git rm test/widget/app_smoke_test.dart`

- [ ] **Step 8: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

If a widget test hangs on a database query, wrap that query in `tester.runAsync(...)`. The drift native executor sometimes needs the real event loop.

- [ ] **Step 9: Commit and push**

```bash
git add -A
git commit -m "feat: add app shell with Today, Goals and Journal tabs"
git push
```

---

### Task 8: Capture button and sheet

**Files:**
- Create: `lib/features/capture/capture_sheet.dart`, `lib/features/capture/capture_button.dart`, `test/widget/capture_test.dart`
- Modify: `lib/ui/home_shell.dart` (add the floating button)

**Interfaces:**
- Consumes: `captureRepositoryProvider` (Task 7), and `Motion`, `motion()` and `context.tide` (Task 4).
- Produces:
  - `Future<bool> showCaptureSheet(BuildContext context)`: returns true if something was saved.
  - `CaptureSheet`
  - `CaptureButton`: tooltip `'Capture a thought'`.

- [ ] **Step 1: Write the failing widget test**

`test/widget/capture_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Capture a thought'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving a thought closes the sheet and confirms', (tester) async {
    final db = await pumpTideApp(tester);
    await openSheet(tester);
    expect(find.text('Capture a thought'), findsWidgets);

    await tester.enterText(find.byType(TextField), '  Book a table for Friday  ');
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Saved to your inbox'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.captures).get());
    expect(rows!.single.body, 'Book a table for Friday');
    await disposeTideApp(tester, db);
  });

  testWidgets('blank text shows a gentle error and saves nothing', (tester) async {
    final db = await pumpTideApp(tester);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Type something first'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.captures).get());
    expect(rows, isEmpty);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(find.text('Type something first'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('double-tapping save stores one capture', (tester) async {
    final db = await pumpTideApp(tester);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Only once');
    await tester.tap(find.text('Save to inbox'));
    await tester.tap(find.text('Save to inbox'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => db.select(db.captures).get());
    expect(rows, hasLength(1));
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/capture_test.dart`
Expected: FAIL, because no widget has the tooltip 'Capture a thought'.

- [ ] **Step 3: Implement `lib/features/capture/capture_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

Future<bool> showCaptureSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion(context, Motion.sheet),
      reverseDuration: motion(context, Motion.quick),
    ),
    builder: (_) => const CaptureSheet(),
  );
  return saved ?? false;
}

class CaptureSheet extends ConsumerStatefulWidget {
  const CaptureSheet({super.key});

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Type something first');
      return;
    }
    _saving = true;
    try {
      await ref.read(captureRepositoryProvider).add(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Capture a thought', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Book a table for Friday', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save to inbox')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `lib/features/capture/capture_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/motion.dart';
import 'capture_sheet.dart';

class CaptureButton extends StatefulWidget {
  const CaptureButton({super.key});

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton> {
  bool _open = false;

  Future<void> _capture() async {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _open = true);
    final saved = await showCaptureSheet(context);
    if (!mounted) return;
    setState(() => _open = false);
    if (saved) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Saved to your inbox'),
          duration: Duration(seconds: 2),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _capture,
      tooltip: 'Capture a thought',
      child: AnimatedRotation(
        turns: _open ? 0.125 : 0,
        duration: motion(context, Motion.sheet),
        curve: Motion.ease,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
```

- [ ] **Step 5: Add the button to the shell**

In `lib/ui/home_shell.dart`, add the import:

```dart
import '../features/capture/capture_button.dart';
```

Then add these two lines inside `Scaffold(...)`, directly after `body: shell,`:

```dart
      floatingActionButton: const CaptureButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
```

- [ ] **Step 6: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 7: Commit and push**

```bash
git add lib/features/capture lib/ui/home_shell.dart test/widget/capture_test.dart
git commit -m "feat: add quick capture button and sheet"
git push
```

---

### Task 9: Inbox line and Inbox screen

**Files:**
- Create: `lib/features/capture/providers.dart`, `lib/features/today/inbox_line.dart`, `lib/features/capture/inbox_screen.dart`, `test/widget/inbox_test.dart`
- Modify: `lib/features/today/today_screen.dart`, `lib/router.dart`

**Interfaces:**
- Consumes: `captureRepositoryProvider`, `Capture` and `calmPage`.
- Produces:
  - Providers: `inboxProvider` (`StreamProvider<List<Capture>>`) and `inboxCountProvider` (`StreamProvider<int>`).
  - `String inboxLabel(int count)`
  - Widgets: `InboxLine` and `InboxScreen`.
  - Route: `/today/inbox`.

- [ ] **Step 1: Write the failing widget test**

`test/widget/inbox_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/today/inbox_line.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> capture(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('Capture a thought'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();
  }

  test('inboxLabel pluralises', () {
    expect(inboxLabel(1), '1 thought in your inbox');
    expect(inboxLabel(3), '3 thoughts in your inbox');
  });

  testWidgets('inbox line only appears when there is something to sort', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.textContaining('in your inbox'), findsNothing);

    await capture(tester, 'Book a table for Friday');
    expect(find.text('1 thought in your inbox'), findsOneWidget);

    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Book a table for Friday'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('archiving the last capture shows the empty state, and Undo restores it',
      (tester) async {
    final db = await pumpTideApp(tester);
    await capture(tester, 'Water the plants');
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Water the plants'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Water the plants'), findsNothing);
    expect(find.text('Nothing to sort'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Water the plants'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('long captures are truncated to four lines in the inbox', (tester) async {
    final db = await pumpTideApp(tester);
    final long = List.filled(400, 'word').join(' ');
    await capture(tester, long);
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 4);
    expect(text.overflow, TextOverflow.ellipsis);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/inbox_test.dart`
Expected: FAIL, because `inbox_line.dart` is not found.

- [ ] **Step 3: Implement `lib/features/capture/providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/capture_repository.dart';

final inboxProvider = StreamProvider<List<Capture>>(
  (ref) => ref.watch(captureRepositoryProvider).watchInbox(),
);

final inboxCountProvider = StreamProvider<int>(
  (ref) => ref.watch(captureRepositoryProvider).watchInboxCount(),
);
```

- [ ] **Step 4: Implement `lib/features/today/inbox_line.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../capture/providers.dart';

String inboxLabel(int count) =>
    count == 1 ? '1 thought in your inbox' : '$count thoughts in your inbox';

class InboxLine extends ConsumerWidget {
  const InboxLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = switch (ref.watch(inboxCountProvider)) {
      AsyncData(:final value) => value,
      _ => 0,
    };
    final c = context.tide;
    return AnimatedSwitcher(
      duration: motion(context, Motion.quick),
      switchInCurve: Motion.ease,
      child: count == 0
          ? const SizedBox.shrink()
          : InkWell(
              key: const ValueKey('inbox-line'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.go('/today/inbox'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined, size: 18, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(inboxLabel(count), style: TideType.body(c.ink))),
                    Icon(Icons.chevron_right, size: 20, color: c.muted),
                  ],
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 5: Implement `lib/features/capture/inbox_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/capture_repository.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'providers.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Hidden locally the moment a tile is dismissed, before the DB stream catches up,
  /// so a dismissed Dismissible is never rebuilt.
  final _hidden = <String>{};

  Future<void> _archive(Capture capture) async {
    final repo = ref.read(captureRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(capture.id));
    await repo.archive(capture.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Archived'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.unarchive(capture.id);
            if (mounted) setState(() => _hidden.remove(capture.id));
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final inbox = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Inbox', style: TideType.title(c.ink))),
      body: switch (inbox) {
        AsyncData(:final value) => _list(value.where((x) => !_hidden.contains(x.id)).toList()),
        AsyncError() =>
          Center(child: Text("Couldn't load your inbox.", style: TideType.body(c.muted))),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _list(List<Capture> captures) {
    final c = context.tide;
    if (captures.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 32, color: c.muted),
            const SizedBox(height: 12),
            Text('Nothing to sort', style: TideType.title(c.ink)),
            const SizedBox(height: 4),
            Text('Anything you capture with + lands here.', style: TideType.body(c.muted)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: captures.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final capture = captures[i];
        return Dismissible(
          key: ValueKey(capture.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _archive(capture),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.archive_outlined, color: c.muted),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
            child: Text(
              capture.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TideType.body(c.ink),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 6: Wire the inbox line into Today, and the route into the router**

In `lib/features/today/today_screen.dart`, add `import 'inbox_line.dart';` and replace the `children` list with:

```dart
        children: const [
          TodayHeader(),
          SizedBox(height: 16),
          InboxLine(),
        ],
```

In `lib/router.dart`, add `import 'features/capture/inbox_screen.dart';` and replace the `/today` route with:

```dart
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'inbox',
                    pageBuilder: (context, state) => calmPage(state, const InboxScreen()),
                  ),
                ],
              ),
```

- [ ] **Step 7: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 8: Commit and push**

```bash
git add lib test/widget/inbox_test.dart
git commit -m "feat: add inbox line and inbox screen with archive and undo"
git push
```

---

### Task 10: Run it on the Samsung

**Files:** none. This task is device verification only.

**Interfaces:**
- Consumes: the whole app.
- Produces: a release build installed on Jason's phone, and a checked-off feel list.

- [ ] **Step 1: USER STEP — enable USB debugging**

Jason does this on the phone:
1. Settings → About phone → Software information → tap **Build number** 7 times.
2. Settings → Developer options → turn on **USB debugging**.
3. Plug the phone into the Mac and tap **Allow** on the phone's prompt.

- [ ] **Step 2: Confirm the phone is visible**

Run: `flutter devices`
Expected: a line like `SM-xxxx (mobile) • <id> • android-arm64 • Android 1x (API 3x)`.

- [ ] **Step 3: Build and install a release APK**

```bash
flutter build apk --release
flutter install -d <device-id-from-step-2>
```

Expected: `Installing build/app/outputs/flutter-apk/app-release.apk...` and the app appears on the phone as **Tide**.

Note: this APK is signed with the debug key, which is fine for a personal install. Proper signing comes in Milestone 5.

- [ ] **Step 4: USER STEP — feel check with Jason**

Walk through this list together and note anything that feels off:
- [ ] The greeting and date are right, and the fonts look like Fraunces (soft serif) and Inter.
- [ ] Switching Android to dark mode changes the theme calmly.
- [ ] Tapping + gives a light haptic tap. The sheet glides up with the keyboard already open, and + turns into ×.
- [ ] Saving shows "Saved to your inbox", and the inbox line appears on Today.
- [ ] Swiping a capture away shows "Archived · Undo", and Undo brings it back.
- [ ] Tab switching feels instant, and the Inbox screen fades in gently.
- [ ] Nothing stutters while scrolling.

- [ ] **Step 5: Record any tuning notes, then commit and push**

Put any notes from Step 4 into `docs/superpowers/plans/2026-09-28-m1-foundation-notes.md` (skip this if there are none), then:

```bash
git add -A
git commit -m "docs: record Milestone 1 device check"
git push
```
