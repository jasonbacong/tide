# Tide

A calm personal "today" app: quick capture, tasks, habits, check-ins and goals. Flutter, Android first.

- Design: `docs/superpowers/specs/2026-09-28-personal-life-app-design.md`
- Plans: `docs/superpowers/plans/`

Run tests: `flutter test` · Run on phone: `flutter run`

## Installing on the phone (keeps your data)

```bash
TIDE_ALLOW_DEBUG_SIGNING=1 flutter build apk --release   # until android/key.properties exists
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Never use `flutter install`: it uninstalls the app first, which erases everything in it.
`flutter run` installs a separate development app (`com.jasongrech.tide.debug`), so it can't touch the real one.
