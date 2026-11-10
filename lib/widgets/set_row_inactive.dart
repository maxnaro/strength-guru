import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class SetRowInactive extends StatelessWidget {
  final int setIndex;
  final int targetReps;
  final int targetRir;
  final VoidCallback? onTap;

  const SetRowInactive({
    super.key,
    required this.setIndex,
    required this.targetReps,
    required this.targetRir,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: p.chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${setIndex + 1}',
                    style: SGText.mono(11, color: p.textFaint),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$targetReps reps · RIR $targetRir',
                  style: SGText.mono(12, color: p.textDim),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
