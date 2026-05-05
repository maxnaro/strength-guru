import 'package:flutter/material.dart';
import '../db/database.dart';
import '../theme/tokens.dart';

class SetRowDone extends StatelessWidget {
  final int setIndex;
  final SetEntry entry;
  final int targetRir;
  final Color groupColor;
  final VoidCallback? onTap;

  const SetRowDone({
    super.key,
    required this.setIndex,
    required this.entry,
    required this.targetRir,
    required this.groupColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final rir = entry.rir;
    final belowTarget = rir != null && rir < targetRir;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Set index tile
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: p.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${setIndex + 1}',
                  style: SGText.mono(11, color: p.success),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Weight readout
            _Readout(
              label: 'KG',
              value: entry.weight != null ? _fmt(entry.weight!) : '—',
              color: p.text,
            ),
            const SizedBox(width: 12),
            // Reps readout
            _Readout(
              label: 'REPS',
              value: entry.reps?.toString() ?? '—',
              color: p.text,
            ),
            const SizedBox(width: 12),
            // RIR readout
            _Readout(
              label: 'RIR',
              value: entry.rir?.toString() ?? '—',
              color: belowTarget ? p.warn : p.text,
            ),
            const Spacer(),
            if (onTap != null)
              Icon(Icons.edit_outlined, size: 14, color: p.textFaint)
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.success.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.check, size: 14, color: p.success),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class _Readout extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Readout({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: SGText.mono(8, color: p.textFaint)),
        Text(value, style: SGText.display(14, color: color)),
      ],
    );
  }
}
