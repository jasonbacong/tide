import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/enums.dart';
import 'data/providers.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/settings/backup_section.dart';
import 'router.dart';
import 'ui/motion.dart';
import 'ui/theme.dart';

class TideApp extends ConsumerStatefulWidget {
  const TideApp({super.key});

  @override
  ConsumerState<TideApp> createState() => _TideAppState();
}

class _TideAppState extends ConsumerState<TideApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildRouter();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(nowProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  bool get _reduceMotion =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  ThemeMode _mode(ThemePreference p) => switch (p) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(dayPeriodProvider);
    final light = buildTheme(Brightness.light, period);
    final dark = buildTheme(Brightness.dark, period);
    // `.value` keeps the last settings during any reload, so navigation is never reset.
    final settings = ref.watch(settingsProvider).value;
    return switch (settings) {
      final value? when value.name.isEmpty => MaterialApp(
          title: 'Tide',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: _mode(value.theme),
          home: const WelcomeScreen(footer: RestoreFromBackupButton()),
        ),
      final value? => MaterialApp.router(
          title: 'Tide',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: _mode(value.theme),
          themeAnimationDuration: _reduceMotion ? Duration.zero : Motion.crossfade,
          themeAnimationCurve: Motion.ease,
          routerConfig: _router,
        ),
      null => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          home: const Scaffold(),
        ),
    };
  }
}
