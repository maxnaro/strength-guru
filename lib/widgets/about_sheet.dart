import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../theme/sg_atoms.dart';
import '../services/backup_service.dart';

const _gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
const _repoUrl = 'https://github.com/maxnaro/strength-guru';

class AboutSheet extends ConsumerStatefulWidget {
  const AboutSheet({super.key});

  @override
  ConsumerState<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends ConsumerState<AboutSheet> {
  String _version = '…';
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final sha = _gitSha.length > 7 ? _gitSha.substring(0, 7) : _gitSha;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SGStat(
                label: 'VERSION',
                value: _version,
                accentBar: p.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SGStat(
                label: 'REVISION',
                value: sha,
                accentBar: p.accent.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SGButton.soft(
          label: 'GitHub Repository',
          leadingIcon: Icon(Icons.code, size: 18, color: p.accent),
          color: p.accent,
          fullWidth: true,
          onTap: () => launchUrl(
            Uri.parse(_repoUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SGButton.soft(
                label: 'Backup',                
                leadingIcon: Icon(Icons.backup_outlined, size: 18, color: p.accent),
                fullWidth: true,
                onTap: _isWorking ? null : _handleBackup,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SGButton.soft(
                label: 'Restore',
                leadingIcon: Icon(Icons.settings_backup_restore, size: 18, color: p.accent),
                fullWidth: true,
                onTap: _isWorking ? null : () => _handleRestore(context),
              ),
            ),
          ],
        ),
        if (_isWorking) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(color: p.accent, backgroundColor: p.chipBg),
        ],
      ],
    );
  }

  Future<void> _handleBackup() async {
    setState(() => _isWorking = true);
    try {
      await BackupService.backup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final p = pal(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Restore Data?', style: SGText.display(20, color: p.text)),
        content: Text(
          'This will overwrite all current workout data with the backup file. This cannot be undone.',
          style: SGText.body(15, color: p.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: SGText.body(14, color: p.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore',
                style: SGText.body(14, color: p.accent, weight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isWorking = true);
    try {
      final success = await BackupService.restore(ref);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored successfully')),
        );
        Navigator.pop(context); // Close the sheet
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }
}
