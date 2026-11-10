import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const double kTimelineCellW = 68;
const double kTimelineCellH = 44;
const double kTimelineNameColW = 130;

String formatTimelineReps(List<int> reps) {
  if (reps.isEmpty) return '—';

  final allSame = reps.every((r) => r == reps.first);
  if (allSame) return '${reps.length}×${reps.first}';

  if (reps.length > 1) {
    final top = reps.first;
    final backoffs = reps.sublist(1);
    final allBackoffsSame = backoffs.every((r) => r == backoffs.first);
    if (allBackoffsSame) {
      return '$top + ${backoffs.length}×${backoffs.first}';
    }
  }

  final list = reps.join(',');
  if (list.length > 10) {
    return '${reps.first}..${reps.last}';
  }
  return list;
}

String formatTimelineRir(List<int> rir) {
  if (rir.isEmpty) return '—';
  final allSame = rir.every((r) => r == rir.first);
  if (allSame) return 'RIR ${rir.first}';
  return 'RIR ${rir.join(',')}';
}

class TimelineCell extends StatelessWidget {
  final List<int>? reps;
  final List<int>? rir;
  final Color bgColor;
  final Color borderColor;
  final double borderWidth;
  final SGPalette palette;
  final VoidCallback onTap;

  const TimelineCell({
    super.key,
    required this.reps,
    required this.rir,
    required this.bgColor,
    required this.borderColor,
    required this.borderWidth,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: kTimelineCellW,
        height: kTimelineCellH,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: reps == null
            ? Icon(Icons.add, size: 14, color: palette.textFaint)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatTimelineReps(reps!),
                    style: SGText.display(10, color: palette.text),
                  ),
                  Text(
                    formatTimelineRir(rir ?? const []),
                    style: SGText.mono(7, color: palette.textDim),
                  ),
                ],
              ),
      ),
    );
  }
}
