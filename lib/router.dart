import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/capture/inbox_screen.dart';
import 'features/checkin/check_in_editor_screen.dart';
import 'features/goals/goal_detail_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tasks/later_screen.dart';
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
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'inbox',
                    pageBuilder: (context, state) => calmPage(state, const InboxScreen()),
                  ),
                  GoRoute(
                    path: 'later',
                    pageBuilder: (context, state) => calmPage(state, const LaterScreen()),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) =>
                        calmPage(state, GoalDetailScreen(goalId: state.pathParameters['id']!)),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/journal',
                builder: (context, state) => const JournalScreen(),
                routes: [
                  GoRoute(
                    path: ':date',
                    pageBuilder: (context, state) => calmPage(
                      state,
                      CheckInEditorScreen(date: state.pathParameters['date']!),
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => calmPage(state, const SettingsScreen()),
        ),
      ],
    );
