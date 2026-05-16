import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../models/plan_advisory.dart';
import '../providers.dart';
import '../services/volume_validator.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

class VolumeValidationSheet extends ConsumerStatefulWidget {
  final Mesocycle meso;

  const VolumeValidationSheet({super.key, required this.meso});

  @override
  ConsumerState<VolumeValidationSheet> createState() => _VolumeValidationSheetState();
}

class _VolumeValidationSheetState extends ConsumerState<VolumeValidationSheet> {
  String _experienceLevel = 'intermediate';
  String _goal = 'hypertrophy';
  late int _weekIdx;
  List<PlanAdvisory>? _advisories;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayKeyProvider);
    if (today != null && today.mesoId == widget.meso.id) {
      _weekIdx = today.weekIdx;
    } else {
      _weekIdx = 0;
    }
  }

  Future<void> _runValidation() async {
    setState(() {
      _loading = true;
      _advisories = null;
    });

    try {
      final db = ref.read(dbProvider);
      final importData = await db.exportMesoToImportData(widget.meso.id);

      final results = VolumeValidator.validate(
        importData,
        experienceLevel: _experienceLevel,
        goal: _goal,
        weekToCheck: _weekIdx,
      );

      if (mounted) {
        setState(() {
          _advisories = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Volume Check', style: SGText.display(22, color: p.text)),
              const SizedBox(height: 4),
              Text(
                'Verify your weekly sets against recommended MEV/MRV ranges.',
                style: SGText.body(14, color: p.textDim),
              ),
              const SizedBox(height: 24),

              // ── Experience Level ───────────────────────────────────
              Text('Experience Level', style: SGText.body(13, color: p.textDim)),
              const SizedBox(height: 8),
              _ExperiencePicker(
                value: _experienceLevel,
                palette: p,
                onChanged: (v) => setState(() => _experienceLevel = v),
              ),
              const SizedBox(height: 20),

              // ── Goal ──────────────────────────────────────────────
              Text('Goal', style: SGText.body(13, color: p.textDim)),
              const SizedBox(height: 8),
              _GoalPicker(
                value: _goal,
                palette: p,
                onChanged: (v) => setState(() => _goal = v),
              ),
              const SizedBox(height: 20),

              // ── Target Week ───────────────────────────────────────
              Text('Target Week', style: SGText.body(13, color: p.textDim)),
              const SizedBox(height: 8),
            ],
          ),
        ),

        _WeekPickerStrip(
          numWeeks: widget.meso.numWeeks,
          value: _weekIdx,
          palette: p,
          onChanged: (v) => setState(() => _weekIdx = v),
        ),

        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SGButton.solid(
            label: 'Run Validation',
            color: p.text,
            fullWidth: true,
            onTap: _loading ? null : _runValidation,
          ),
        ),

        const SizedBox(height: 20),

        // ── Results ───────────────────────────────────────────────
        if (_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: p.accent),
            ),
          )
        else if (_advisories != null)
          _ResultsView(advisories: _advisories!, palette: p)
        else
          const SizedBox(height: 20),

        SizedBox(height: bottomPad + 16),
      ],
    );
  }
}

// ── Pickers ───────────────────────────────────────────────────────────────────

class _ExperiencePicker extends StatelessWidget {
  final String value;
  final SGPalette palette;
  final ValueChanged<String> onChanged;

  const _ExperiencePicker({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  static const _options = [
    ('beginner', 'Beginner', '< 1 yr'),
    ('intermediate', 'Intermediate', '1–4 yrs'),
    ('advanced', 'Advanced', '4+ yrs'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: _options.map((opt) {
        final (val, label, sub) = opt;
        final selected = value == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                right: val != 'advanced' ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? p.accent.withValues(alpha: 0.12) : p.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? p.accent.withValues(alpha: 0.4) : p.border,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: SGText.body(11,
                        color: selected ? p.accent : p.text,
                        weight: selected ? FontWeight.w600 : FontWeight.w400),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                  Text(
                    sub,
                    style: SGText.mono(8, color: p.textFaint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  final String value;
  final SGPalette palette;
  final ValueChanged<String> onChanged;

  const _GoalPicker({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  static const _options = [
    ('strength', 'Strength', '1–6 reps'),
    ('hypertrophy', 'Hypertrophy', '6–15 reps'),
    ('mix', 'Mix', 'blend'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: _options.map((opt) {
        final (val, label, sub) = opt;
        final selected = value == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                right: val != 'mix' ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? p.accent.withValues(alpha: 0.12) : p.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? p.accent.withValues(alpha: 0.4) : p.border,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: SGText.body(11,
                        color: selected ? p.accent : p.text,
                        weight: selected ? FontWeight.w600 : FontWeight.w400),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                  Text(
                    sub,
                    style: SGText.mono(8, color: p.textFaint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WeekPickerStrip extends StatelessWidget {
  final int numWeeks;
  final int value;
  final SGPalette palette;
  final ValueChanged<int> onChanged;

  const _WeekPickerStrip({
    required this.numWeeks,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;

    return Stack(
      children: [
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: numWeeks,
            itemBuilder: (ctx, i) {
              final active = value == i;
              return GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: active ? p.text : p.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'WEEK ${i + 1}',
                      style: SGText.mono(10,
                          color: active ? p.bg : p.textDim,
                          weight: active ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: -1,
          top: 0,
          bottom: 0,
          width: 30,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [p.bg, p.bg.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final List<PlanAdvisory> advisories;
  final SGPalette palette;

  const _ResultsView({required this.advisories, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;

    if (advisories.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.success.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: p.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Volume looks optimal for this week!',
                style: SGText.body(14, color: p.success, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.warn.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.warn.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: p.warn, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Plan advisories (${advisories.length})',
                  style: SGText.body(13, color: p.warn, weight: FontWeight.w600),
                ),
              ],
            ),
            children: advisories
                .map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: SGText.mono(12, color: p.textDim)),
                          Expanded(
                            child: Text(a.message,
                                style: SGText.mono(12, color: p.textDim)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
