import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../models/plan_advisory.dart';
import '../providers.dart';
import '../screens/meso_import_screen.dart';
import '../services/llm_service.dart';
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
  String _sportContext = '';
  List<PlanAdvisory>? _advisories;
  bool _loading = false;
  final _sportController = TextEditingController();

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
  void dispose() {
    _sportController.dispose();
    super.dispose();
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

              // ── Sport / Context ────────────────────────────────────
              Text('Sport / Context (optional)', style: SGText.body(13, color: p.textDim)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border, width: 0.5),
                ),
                child: TextField(
                  controller: _sportController,
                  onChanged: (v) => _sportContext = v,
                  style: SGText.body(13, color: p.text),
                  decoration: InputDecoration(
                    hintText: 'climbing, running, BJJ…',
                    hintStyle: SGText.body(13, color: p.textFaint),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),

            ],
          ),
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
          _ResultsView(
            advisories: _advisories!,
            palette: p,
            onFixRequested: _onFixRequested,
          )
        else
          const SizedBox(height: 20),

        SizedBox(height: bottomPad + 16),
      ],
    );
  }

  Future<void> _onFixRequested() async {
    final db = ref.read(dbProvider);
    final url = await db.getSetting('llm_api_url') ?? LlmService.defaultUrl;
    final importData = await db.exportMesoToImportData(widget.meso.id);
    final exercises = await db.allExercises();
    final lib = exercises.map((e) => (name: e.name, group: e.group)).toList();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MesoImportScreen(
          dataProducer: (onProgress, onReasoning) => LlmService().fixPlanAdvisories(
            importData,
            _advisories!,
            apiUrl: url,
            experienceLevel: _experienceLevel,
            goal: _goal,
            sportContext: _sportContext,
            exerciseLibrary: lib,
            onReasoning: onReasoning,
          ),
          fixProducer: (currentData, advisories, onReasoning) =>
              LlmService().fixPlanAdvisories(
            currentData,
            advisories,
            apiUrl: url,
            experienceLevel: _experienceLevel,
            goal: _goal,
            sportContext: _sportContext,
            exerciseLibrary: lib,
            onReasoning: onReasoning,
          ),
        ),
      ),
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

// ── Results ───────────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final List<PlanAdvisory> advisories;
  final SGPalette palette;
  final VoidCallback? onFixRequested;

  const _ResultsView({
    required this.advisories,
    required this.palette,
    this.onFixRequested,
  });

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
                'Volume looks optimal across the mesocycle!',
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
                Icon(Icons.warning_amber_rounded, color: p.warn, size: 24),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '(${advisories.length})',
                    style: SGText.body(16, color: p.warn, weight: FontWeight.w600),
                  ),
                ),
                if (onFixRequested != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SGButton.ghost(
                      label: 'Fix with AI',
                      leadingIcon: Icon(Icons.auto_awesome, size: 14, color: p.warn),
                      color: p.warn,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      onTap: onFixRequested,
                    ),
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
