import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../screens/meso_import_screen.dart';
import '../theme/tokens.dart';
import '../theme/sg_atoms.dart';

class MesoSwitcher extends ConsumerStatefulWidget {
  const MesoSwitcher({super.key});

  @override
  ConsumerState<MesoSwitcher> createState() => _MesoSwitcherState();
}

class _MesoSwitcherState extends ConsumerState<MesoSwitcher> {
  bool _creating = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final mesosAsync = ref.watch(allMesosProvider);
    final activeMeso = ref.watch(activeMesoProvider).valueOrNull;

    if (_creating) {
      return _CreationForm(
        controller: _nameController,
        mesosCount: mesosAsync.valueOrNull?.length ?? 0,
        palette: p,
        onCreate: _handleCreate,
        onCancel: () => setState(() => _creating = false),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mesocycles', style: SGText.display(20, color: p.text)),
        const SizedBox(height: 4),
        Text('Tap to switch active block.',
            style: SGText.body(13, color: p.textDim)),
        const SizedBox(height: 16),
        mesosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('Error: $e', style: SGText.body(13, color: p.accent)),
          data: (mesos) => Column(
            children: mesos.map((m) {
              final isActive = m.id == activeMeso?.id;
              return _MesoRow(
                meso: m,
                isActive: isActive,
                palette: p,
                onTap: isActive ? null : () => _activate(m),
                onRename: (newName) => _handleRename(m, newName),
                onDuplicate: (newName) => _handleDuplicate(m, newName),
                onDelete: () => _handleDelete(m),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _creating = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: p.chipBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: p.textDim),
                const SizedBox(width: 8),
                Text('New Mesocycle',
                    style: SGText.body(14, color: p.textDim)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _handleImportCsv,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: p.chipBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_outlined, size: 18, color: p.textDim),
                const SizedBox(width: 8),
                Text('Import from CSV',
                    style: SGText.body(14, color: p.textDim)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Starts as a 5-week template. Edit any cell after.',
          style: SGText.body(12, color: p.textFaint),
        ),
      ],
    );
  }

  Future<void> _activate(Mesocycle meso) async {
    final db = ref.read(dbProvider);
    await db.activateMeso(meso.id);
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleRename(Mesocycle meso, String newName) async {
    final db = ref.read(dbProvider);
    await db.renameMeso(meso.id, newName);
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleDuplicate(Mesocycle meso, String newName) async {
    final db = ref.read(dbProvider);
    await db.duplicateMeso(meso.id, newName);
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleDelete(Mesocycle meso) async {
    final db = ref.read(dbProvider);
    await db.deleteMeso(meso.id);
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleCreate(String name) async {
    final db = ref.read(dbProvider);
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await db.createMeso(trimmed);
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleImportCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || !mounted) return;

    final file = result.files.single;
    String csvContent;

    try {
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) return;
      
      try {
        csvContent = utf8.decode(bytes);
      } catch (_) {
        // Fallback to latin1 for non-UTF8 CSVs (common with Excel "ANSI" exports)
        csvContent = latin1.decode(bytes);
      }
    } catch (e) {
      debugPrint('Error reading CSV: $e');
      return;
    }

    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop(); // close switcher sheet
    nav.push(MaterialPageRoute(
      builder: (_) => MesoImportScreen(csvContent: csvContent),
    ));
  }
}

Future<String?> _showNameDialog(
    BuildContext context, String title, String initialValue) async {
  final controller = TextEditingController(text: initialValue);
  final p = pal(context);
  return showSGSheet<String>(
    context,
    isScrollControlled: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SGText.display(20, color: p.text),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          autofocus: true,
          style: SGText.body(15, color: p.text),
          decoration: InputDecoration(
            hintText: 'Name',
            hintStyle: SGText.body(15, color: p.textFaint),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: SGButton.ghost(
              label: 'Cancel',
              color: p.textDim,
              fullWidth: true,
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SGButton.solid(
              label: 'Confirm',
              color: p.accent,
              fullWidth: true,
              onTap: () => Navigator.pop(context, controller.text.trim()),
            ),
          ),
        ]),
      ],
    ),
  );
}

class _MesoRow extends StatelessWidget {
  final Mesocycle meso;
  final bool isActive;
  final SGPalette palette;
  final VoidCallback? onTap;
  final Function(String newName)? onRename;
  final Function(String newName)? onDuplicate;
  final VoidCallback? onDelete;

  const _MesoRow({
    required this.meso,
    required this.isActive,
    required this.palette,
    required this.onTap,
    this.onRename,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showSGSheet(
          context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                meso.name,
                style: SGText.display(20, color: palette.text),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              SGButton.solid(
                label: 'Rename',
                color: palette.accent,
                fullWidth: true,
                onTap: () async {
                  Navigator.pop(context);
                  final newName = await _showNameDialog(context, 'Rename', meso.name);
                  if (newName != null && newName.isNotEmpty) {
                    onRename?.call(newName);
                  }
                },
              ),
              const SizedBox(height: 10),
              SGButton.solid(
                label: 'Duplicate',
                color: palette.accent,
                fullWidth: true,
                onTap: () async {
                  Navigator.pop(context);
                  final newName = await _showNameDialog(context, 'Duplicate', '${meso.name} (Copy)');
                  if (newName != null && newName.isNotEmpty) {
                    onDuplicate?.call(newName);
                  }
                },
              ),
              const SizedBox(height: 10),
              SGButton.solid(
                label: 'Delete',
                color: palette.warn,
                fullWidth: true,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Mesocycle?'),
                      content: Text('Are you sure you want to delete "${meso.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete', style: TextStyle(color: palette.warn)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (context.mounted) Navigator.pop(context);
                    onDelete?.call();
                  }
                },
              ),
              const SizedBox(height: 10),
              SGButton.ghost(
                label: 'Cancel',
                color: palette.textDim,
                fullWidth: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? palette.accent.withValues(alpha: 0.08) : palette.chipBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? palette.accent.withValues(alpha: 0.3) : palette.border,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? palette.accent : palette.textFaint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meso.name,
                      style: SGText.display(16,
                          color: palette.text, weight: FontWeight.w700)),
                  Text(
                    '${meso.numWeeks} WEEKS · '
                    '${DateFormat('yyyy-MM-dd').format(meso.startDate)}',
                    style: SGText.mono(10, color: palette.textFaint),
                  ),
                ],
              ),
            ),
            if (isActive)
              const SGChip('ACTIVE', tone: ChipTone.accent),
          ],
        ),
      ),
    );
  }
}

class _CreationForm extends StatelessWidget {
  final TextEditingController controller;
  final int mesosCount;
  final SGPalette palette;
  final Future<void> Function(String name) onCreate;
  final VoidCallback onCancel;

  const _CreationForm({
    required this.controller,
    required this.mesosCount,
    required this.palette,
    required this.onCreate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = 'Block ${mesosCount + 1}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New Mesocycle', style: SGText.display(20, color: palette.text)),
        const SizedBox(height: 4),
        Text(
          'Starts as a 5-week template. Edit cells after creating.',
          style: SGText.body(13, color: palette.textDim),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          autofocus: true,
          style: SGText.body(15, color: palette.text),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: SGText.body(15, color: palette.textFaint),
          ),
          onSubmitted: (v) =>
              onCreate(v.isEmpty ? placeholder : v),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: SGButton.ghost(
              label: 'Cancel',
              color: palette.textDim,
              fullWidth: true,
              onTap: onCancel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SGButton.solid(
              label: 'Create',
              color: palette.accent,
              fullWidth: true,
              onTap: () {
                final v = controller.text.trim();
                onCreate(v.isEmpty ? placeholder : v);
              },
            ),
          ),
        ]),
      ],
    );
  }
}
