import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/capture_button.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      floatingActionButton: const CaptureButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
