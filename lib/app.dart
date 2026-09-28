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
