import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/backup/backup_service.dart';
import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';

String exportAgeLabel(DateTime? last, DateTime now) {
  if (last == null) return 'Not exported yet';
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(last.year, last.month, last.day))
      .inDays;
  if (days <= 0) return 'Last exported today';
  if (days == 1) return 'Last exported yesterday';
  return 'Last exported $days days ago';
}

final shareFileProvider = Provider<Future<void> Function(File)>((ref) => (file) async {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Tide backup',
      ));
    });

/// Picks one file. Android may hand back a content URI with no local path, so the
/// bytes are copied into a temporary file in that case.
final pickFileProvider = Provider<Future<File?> Function()>((ref) => () async {
      final picked = await FilePicker.pickFile(type: FileType.any);
      if (picked == null) return null;
      final path = picked.path;
      if (path != null) return File(path);
      final tmp = await getTemporaryDirectory();
      final copy = File('${tmp.path}/import-${DateTime.now().millisecondsSinceEpoch}.tide.json');
      return copy.writeAsBytes(await picked.xFile.readAsBytes());
    });

final backupFilesProvider =
    FutureProvider.autoDispose<List<File>>((ref) => ref.watch(backupServiceProvider).listBackups());

/// Pick a file, then run the import flow (if the screen is still there).
Future<void> pickAndImport(BuildContext context, WidgetRef ref) async {
  final file = await ref.read(pickFileProvider)();
  if (!context.mounted) return;
  await importBackup(context, ref, file);
}

/// Shared import flow: read → confirm → restore. Used by Settings and the welcome screen.
Future<void> importBackup(BuildContext context, WidgetRef ref, File? file) async {
  if (file == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  try {
    final data = await service.read(file);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace everything?'),
        content: const Text('This replaces everything in the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace')),
        ],
      ),
    );
    if (ok != true) return;
    await service.restore(data);
    // Restoring on the welcome screen swaps it for Today, so this context may be gone.
    if (context.mounted) ref.invalidate(backupFilesProvider);
    if (messenger.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
    }
  } on BackupFormatException catch (e) {
    if (messenger.mounted) messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't restore that. Try again")));
    }
  }
}

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(backupServiceProvider).exportFile();
      await ref.read(shareFileProvider)(file);
      await ref.read(settingsRepositoryProvider).markExported();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't export. Try again")));
    }
  }

  static String _label(File f) {
    final s = backupStamp(f);
    if (s.isEmpty) return f.uri.pathSegments.last;
    try {
      return DateFormat('EEE d MMM, HH:mm').format(DateFormat('yyyy-MM-dd-HHmmss').parse(s));
    } on FormatException {
      return f.uri.pathSegments.last;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final now = ref.watch(nowProvider);
    final last = ref.watch(settingsProvider).value?.lastExportAt;
    final files = ref.watch(backupFilesProvider).value ?? const <File>[];
    return TideCard(
      title: 'Backup',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(exportAgeLabel(last, now), style: TideType.body(c.ink)),
        const SizedBox(height: 4),
        Text(
            'Save a copy somewhere safe, like Google Drive. Automatic backups live on this phone '
            'and are lost if the app is uninstalled.',
            style: TideType.label(c.muted)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: FilledButton(onPressed: () => _export(context, ref), child: const Text('Export'))),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => pickAndImport(context, ref),
              child: const Text('Import'),
            ),
          ),
        ]),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Automatic backups', style: TideType.label(c.muted)),
          for (final f in files)
            Row(children: [
              Expanded(child: Text(_label(f), style: TideType.body(c.ink))),
              TextButton(onPressed: () => importBackup(context, ref, f), child: const Text('Restore')),
            ]),
        ],
      ]),
    );
  }
}

class RestoreFromBackupButton extends ConsumerWidget {
  const RestoreFromBackupButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: () => pickAndImport(context, ref),
        child: const Text('Restore from a backup'),
      );
}
