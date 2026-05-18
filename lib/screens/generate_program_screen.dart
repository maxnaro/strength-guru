import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/queries.dart';
import '../providers.dart';
import '../screens/meso_import_screen.dart';
import '../services/llm_service.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

class GenerateProgramScreen extends ConsumerStatefulWidget {
  const GenerateProgramScreen({super.key});

  @override
  ConsumerState<GenerateProgramScreen> createState() =>
      _GenerateProgramScreenState();
}

enum _ExperienceLevel { beginner, intermediate, advanced }

enum _Goal { strength, hypertrophy, mix }

class _GenerateProgramScreenState extends ConsumerState<GenerateProgramScreen> {
  final _descriptionController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _sportController = TextEditingController();
  int _numWeeks = 5;
  int _trainingDays = 4;
  _ExperienceLevel _experience = _ExperienceLevel.intermediate;
  _Goal _goal = _Goal.mix;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _apiUrlController.dispose();
    _sportController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(dbProvider);
    final savedUrl = await db.getSetting('llm_api_url');
    if (mounted) {
      setState(() {
        _apiUrlController.text = savedUrl ?? LlmService.defaultUrl;
      });
    }
  }

  Future<void> _onGenerate() async {
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) return;

    final url = _apiUrlController.text.trim();
    final db = ref.read(dbProvider);
    await db.setSetting('llm_api_url', url);
    await db.setSetting('llm_use_external', 'true');
    final exercises = await db.allExercises();

    if (!mounted) return;
    final weeks = _numWeeks;
    final exp = _experience.name; // 'beginner' | 'intermediate' | 'advanced'
    final goalStr = _goal.name;   // 'strength' | 'hypertrophy' | 'mix'
    final days = _trainingDays;
    final sport = _sportController.text.trim();
    final exerciseLibrary = exercises.map((e) => (name: e.name, group: e.group)).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MesoImportScreen(
          dataProducer: (onProgress, onReasoning) => LlmService().interpretDescription(
            desc,
            weeks,
            apiUrl: url,
            experienceLevel: exp,
            goal: goalStr,
            trainingDays: days,
            sportContext: sport,
            exerciseLibrary: exerciseLibrary,
            onProgress: onProgress,
            onReasoning: onReasoning,
          ),
          fixProducer: (currentData, advisories, onReasoning) =>
              LlmService().fixPlanAdvisories(
            currentData,
            advisories,
            apiUrl: url,
            experienceLevel: exp,
            goal: goalStr,
            sportContext: sport,
            description: desc,
            exerciseLibrary: exerciseLibrary,
            onReasoning: onReasoning,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Generate Program', style: SGText.display(17, color: p.text)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Describe your program',
                        style: SGText.display(20, color: p.text)),
                    const SizedBox(height: 8),
                    Text(
                      'Include split style, goals, experience level, and any exercise preferences. More detail, better output.',
                      style: SGText.body(14, color: p.textDim),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 6,
                        style: SGText.body(14, color: p.text),
                        decoration: InputDecoration(
                          hintText:
                              '4-day upper/lower split, 6 weeks, progressive overload, compound-focused, intermediate lifter…',
                          hintStyle: SGText.body(14, color: p.textFaint),
                          border: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Experience Level',
                        style: SGText.body(13, color: p.textDim)),
                    const SizedBox(height: 8),
                    _ExperiencePicker(
                      value: _experience,
                      palette: p,
                      onChanged: (v) => setState(() => _experience = v),
                    ),
                    const SizedBox(height: 24),
                    Text('Goal', style: SGText.body(13, color: p.textDim)),
                    const SizedBox(height: 8),
                    _GoalPicker(
                      value: _goal,
                      palette: p,
                      onChanged: (v) => setState(() => _goal = v),
                    ),
                    const SizedBox(height: 24),
                    SGStepper(
                      value: _trainingDays,
                      min: 1,
                      max: 7,
                      step: 1,
                      label: 'TRAINING DAYS / WEEK',
                      accentColor: p.accent,
                      onChanged: (v) => setState(() => _trainingDays = v.toInt()),
                    ),
                    const SizedBox(height: 24),
                    SGStepper(
                      value: _numWeeks,
                      min: 1,
                      max: 16,
                      step: 1,
                      label: 'WEEKS',
                      accentColor: p.accent,
                      onChanged: (v) => setState(() => _numWeeks = v.toInt()),
                    ),
                    const SizedBox(height: 24),
                    Text('Sport / Context (optional)', style: SGText.body(13, color: p.textDim)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _sportController,
                        style: SGText.body(14, color: p.text),
                        decoration: InputDecoration(
                          hintText: 'climbing, running, BJJ, general fitness…',
                          hintStyle: SGText.body(14, color: p.textFaint),
                          border: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('API Endpoint', style: SGText.body(13, color: p.textDim)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _apiUrlController,
                        style: SGText.mono(13, color: p.text),
                        decoration: InputDecoration(
                          hintText: 'http://...',
                          hintStyle: SGText.mono(13, color: p.textFaint),
                          border: InputBorder.none,
                          fillColor: Colors.transparent,
                          labelText: 'OpenAI-compatible endpoint',
                          labelStyle: SGText.body(11, color: p.textFaint),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    SGButton.solid(
                      label: 'Generate Program',
                      color: p.accent,
                      fullWidth: true,
                      onTap: _onGenerate,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  final _Goal value;
  final SGPalette palette;
  final ValueChanged<_Goal> onChanged;

  const _GoalPicker({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  static const _options = [
    (_Goal.strength, 'Strength', '1–6 reps'),
    (_Goal.hypertrophy, 'Hypertrophy', '6–15 reps'),
    (_Goal.mix, 'Mix', 'blend'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: _options.map((opt) {
        final (goal, label, sub) = opt;
        final selected = value == goal;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(goal),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                right: goal != _Goal.mix ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? p.accent.withValues(alpha: 0.12)
                    : p.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? p.accent.withValues(alpha: 0.4)
                      : p.border,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: SGText.body(13,
                        color: selected ? p.accent : p.text,
                        weight: selected ? FontWeight.w600 : FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    sub,
                    style: SGText.mono(10, color: p.textFaint),
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

class _ExperiencePicker extends StatelessWidget {
  final _ExperienceLevel value;
  final SGPalette palette;
  final ValueChanged<_ExperienceLevel> onChanged;

  const _ExperiencePicker({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  static const _options = [
    (_ExperienceLevel.beginner, 'Beginner', '< 1 yr'),
    (_ExperienceLevel.intermediate, 'Intermediate', '1–4 yrs'),
    (_ExperienceLevel.advanced, 'Advanced', '4+ yrs'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: _options.map((opt) {
        final (level, label, sub) = opt;
        final selected = value == level;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                right: level != _ExperienceLevel.advanced ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? p.accent.withValues(alpha: 0.12)
                    : p.chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? p.accent.withValues(alpha: 0.4)
                      : p.border,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: SGText.body(13,
                        color: selected ? p.accent : p.text,
                        weight: selected ? FontWeight.w600 : FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    sub,
                    style: SGText.mono(10, color: p.textFaint),
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
