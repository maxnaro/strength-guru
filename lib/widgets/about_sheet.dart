import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../theme/sg_atoms.dart';

const _gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
const _repoUrl = 'https://github.com/maxnaro/strength-guru';

class AboutSheet extends StatefulWidget {
  const AboutSheet({super.key});

  @override
  State<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<AboutSheet> {
  String _version = '…';

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
      ],
    );
  }
}
