import 'dart:io';

import 'package:drift/native.dart';
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
  DeviceRecoveryActions({Future<Directory> Function()? documentsDir})
      : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDir;

  Future<Directory> _backups() async => Directory('${(await _documentsDir()).path}/backups');

  @override
  Future<File?> latestBackup() async {
    final dir = await _backups();
    if (!await dir.exists()) return null;
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.tide.json'))
        .cast<File>()
        .toList();
    final sorted = sortBackupsNewestFirst(files, DateTime.now());
    return sorted.isEmpty ? null : sorted.first;
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
    final docs = await _documentsDir();
    final live = File('${docs.path}/tide.sqlite');
    final staging = File('${docs.path}/tide-restoring.sqlite');
    Future<void> removeStaging() async {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('${staging.path}$suffix');
        if (await f.exists()) await f.delete();
      }
    }

    // 1. Restore into a separate file. If this fails, the live database is untouched.
    await removeStaging();
    final fresh = AppDatabase(NativeDatabase(staging));
    try {
      await BackupCodec.restore(fresh, data);
    } catch (_) {
      await fresh.close();
      await removeStaging();
      rethrow;
    }
    await fresh.close();

    // 2. Only now move the broken database aside and put the restored one in place.
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${live.path}$suffix');
      if (await f.exists()) await f.rename('${docs.path}/tide-broken-$stamp.sqlite$suffix');
    }
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${staging.path}$suffix');
      if (await f.exists()) await f.rename('${live.path}$suffix');
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

  String? get _latestLabel {
    final s = _latest == null ? '' : backupStamp(_latest!);
    if (s.isEmpty) return null;
    try {
      return DateFormat('EEE d MMM, HH:mm').format(DateFormat('yyyy-MM-dd-HHmmss').parse(s));
    } on FormatException {
      return null;
    }
  }

  /// A one-off problem (e.g. a locked file) may clear on its own: reopen without touching data.
  Future<void> _retry() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onRecovered();
    } catch (_) {
      if (mounted) setState(() => _error = "Still couldn't open it. Try restoring a backup.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              OutlinedButton(onPressed: _retry, child: const Text('Try again')),
              const SizedBox(height: 8),
              if (_latest != null)
                FilledButton(
                  onPressed: () => _restore(_latest),
                  child: const Text('Restore latest backup'),
                ),
              if (_latest != null && _latestLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('From $_latestLabel',
                      textAlign: TextAlign.center, style: TideType.label(c.muted)),
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
