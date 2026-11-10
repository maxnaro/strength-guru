import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../platform/download.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';
import 'ai_jobs_sheet.dart';

class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncClientProvider);
    if (sync == null) return const SizedBox.shrink();
    return StreamBuilder<void>(
      stream: sync.events.stream,
      builder: (context, _) {
        final label = sync.conflicts > 0
            ? '${sync.conflicts} changes need review'
            : sync.pending > 0
            ? '${sync.pending} changes pending sync'
            : sync.connected
            ? 'Synced'
            : 'Offline · saved on this device';
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: InkWell(
            onTap: () => _review(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    sync.connected
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 12)),
                  ),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _review(BuildContext parentContext, WidgetRef ref) async {
    final sync = ref.read(syncClientProvider)!;
    await showSGSheet<void>(
      parentContext,
      maxHeightFraction: .65,
      child: StatefulBuilder(
        builder: (sheetContext, setState) {
          final p = pal(sheetContext);
          return FutureBuilder(
            future: sync.db
                .customSelect('SELECT * FROM sg_outbox ORDER BY rowid')
                .get(),
            builder: (context, snapshot) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync and pending changes',
                  style: SGText.display(20, color: p.text),
                ),
                if (sync.message != null) ...[
                  const SizedBox(height: 8),
                  Text(sync.message!, style: SGText.body(14, color: p.textDim)),
                ],
                const SizedBox(height: 24),
                SGButton.solid(
                  label: 'Retry sync',
                  leadingIcon: Icon(Icons.sync, size: 18, color: p.bg),
                  fullWidth: true,
                  onTap: () async {
                    try {
                      await sync.synchronize();
                    } catch (_) {}
                    if (sheetContext.mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                SGButton.soft(
                  label: 'Export pending changes',
                  color: p.accent,
                  leadingIcon: Icon(
                    Icons.file_download_outlined,
                    size: 18,
                    color: p.accent,
                  ),
                  fullWidth: true,
                  onTap: () async {
                    await downloadBytes(
                      Uint8List.fromList(
                        utf8.encode(await sync.exportPending()),
                      ),
                      'strength-guru-pending.json',
                      'application/json',
                    );
                  },
                ),
                const SizedBox(height: 12),
                SGButton.soft(
                  label: 'Apply app update',
                  color: sync.pending == 0 ? p.accent : p.textFaint,
                  leadingIcon: Icon(
                    Icons.system_update_alt,
                    size: 18,
                    color: sync.pending == 0 ? p.accent : p.textFaint,
                  ),
                  fullWidth: true,
                  onTap: sync.pending == 0
                      ? () {
                          Navigator.pop(sheetContext);
                          showDialog<void>(
                            context: parentContext,
                            builder: (context) => AlertDialog(
                              title: const Text('Reload app update?'),
                              content: const Text(
                                'Your synced changes are safe. This will reload the app.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ref.read(activateUpdateProvider)();
                                  },
                                  child: const Text('Reload'),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                SGButton.ghost(
                  label: 'AI jobs and saved results',
                  color: p.textDim,
                  fullWidth: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showModalBottomSheet<void>(
                      context: parentContext,
                      isScrollControlled: true,
                      builder: (_) => const AiJobsSheet(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'PENDING CHANGES',
                  style: SGText.mono(11, color: p.textFaint, ls: 1.2),
                ),
                const SizedBox(height: 12),
                if (snapshot.hasData && snapshot.data!.isEmpty)
                  Text(
                    'No pending changes.',
                    style: SGText.body(14, color: p.textDim),
                  ),
                for (final row in snapshot.data ?? [])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      row.read<String>('resource'),
                      style: SGText.body(
                        15,
                        weight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    subtitle: Text(
                      row.data['error'] as String? ??
                          'Waiting for server acknowledgement',
                      style: SGText.body(13, color: p.textDim),
                    ),
                    trailing: PopupMenuButton<String>(
                      color: p.surface,
                      iconColor: p.textDim,
                      onSelected: (value) async {
                        if (value == 'keep') {
                          try {
                            await sync.keepLocal(row.read<String>('id'));
                          } catch (_) {}
                        } else {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Discard this local change?'),
                              content: const Text(
                                'Export pending changes first if you want to retain a copy. The server version will be used.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Discard'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await sync.discard(row.read<String>('id'));
                            } catch (_) {}
                          }
                        }
                        if (sheetContext.mounted) setState(() {});
                      },
                      itemBuilder: (_) => [
                        if (row.data['state'] == 'conflict')
                          PopupMenuItem(
                            value: 'keep',
                            child: Text(
                              'Keep my edit',
                              style: SGText.body(14, color: p.text),
                            ),
                          ),
                        PopupMenuItem(
                          value: 'discard',
                          child: Text(
                            'Use server version',
                            style: SGText.body(14, color: p.text),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
