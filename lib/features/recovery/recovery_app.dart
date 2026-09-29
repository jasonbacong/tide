import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/backup/backup_service.dart';
import '../../data/db/app_database.dart';
import '../../ui/day_period.dart';
import '../../ui/theme.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

abstract class RecoveryActions {
  Future<File?> latestBackup();
  Future<File?> pickFile();
  Future<void> resetWith(File backup);
}

class DeviceRecoveryActions implements RecoveryActions {
  Future<Directory> _backups() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/backups');

  @override
  Future<File?> latestBackup() async {
    final dir = await _backups();
    if (!await dir.exists()) return null;
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.tide.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => backupStamp(b).compareTo(backupStamp(a)));
    return files.isEmpty ? null : files.first;
  }

  @override
  Future<File?> pickFile() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return null;
    final path = picked.path;
    if (path != null) return File(path);
    final tmp = await getTemporaryDirectory();
    final copy = File('${tmp.path}/recover-${DateTime.now().millisecondsSinceEpoch}.tide.json');
    return copy.writeAsBytes(await picked.xFile.readAsBytes());
  }

  @override
  Future<void> resetWith(File backup) async {
    final data = BackupCodec.parse(await backup.readAsString()); // validate before touching files
    final dbFile = await AppDatabase.databaseFile();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${dbFile.path}$suffix');
      if (await f.exists()) {
        await f.rename('${dbFile.parent.path}/tide-broken-$stamp.sqlite$suffix');
      }
    }
    final fresh = AppDatabase.open();
    try {
      await BackupCodec.restore(fresh, data);
    } finally {
      await fresh.close();
    }
  }
}

class RecoveryApp extends StatelessWidget {
  const RecoveryApp({super.key, required this.actions, required this.onRecovered});

  final RecoveryActions actions;
  final Future<void> Function() onRecovered;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, PartOfDay.afternoon),
        darkTheme: buildTheme(Brightness.dark, PartOfDay.afternoon),
        home: _RecoveryScreen(actions: actions, onRecovered: onRecovered),
      );
}

class _RecoveryScreen extends StatefulWidget {
  const _RecoveryScreen({required this.actions, required this.onRecovered});

  final RecoveryActions actions;
  final Future<void> Function() onRecovered;

  @override
  State<_RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<_RecoveryScreen> {
  File? _latest;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.actions.latestBackup().then((f) {
      if (mounted) setState(() => _latest = f);
    });
  }

  Future<void> _restore(File? file) async {
    if (file == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.actions.resetWith(file);
      await widget.onRecovered();
    } on BackupFormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't restore that. Try another file.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.healing_outlined, size: 40, color: c.accent),
              const SizedBox(height: 16),
              Text("Tide couldn't open your data",
                  textAlign: TextAlign.center, style: TideType.title(c.ink)),
              const SizedBox(height: 8),
              Text(
                'Your data is still on the phone. You can restore your latest backup or import '
                'a file you exported.',
                textAlign: TextAlign.center,
                style: TideType.body(c.muted),
              ),
              const SizedBox(height: 32),
              if (_latest != null)
                FilledButton(
                  onPressed: () => _restore(_latest),
                  child: const Text('Restore latest backup'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async => _restore(await widget.actions.pickFile()),
                child: const Text('Import a file'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: TideType.body(c.warm)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
