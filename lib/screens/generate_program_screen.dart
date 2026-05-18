import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../models/meso_import_data.dart';
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
  List<Mesocycle> _mesocycles = [];
  String? _basisMesoId;
  String _basisMode = 'inspiration';

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
    final mesos = await db.watchAllMesocycles().first;
    if (mounted) {
      setState(() {
        _apiUrlController.text = savedUrl ?? LlmService.defaultUrl;
        _mesocycles = mesos;
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

    MesoImportData? priorMeso;
    if (_basisMesoId != null) {
      priorMeso = await db.exportMesoToImportData(_basisMesoId!);
    }

    if (!mounted) return;
    final bool progressMode = priorMeso != null && _basisMode == 'progress';
    final weeks = progressMode ? priorMeso.numWeeks : _numWeeks;
    final exp = _experience.name; // 'beginner' | 'intermediate' | 'advanced'
    final goalStr = _goal.name;   // 'strength' | 'hypertrophy' | 'mix'
    final int? days = progressMode ? null : _trainingDays;
    final sport = _sportController.text.trim();
    final exerciseLibrary = exercises.map((e) => (name: e.name, group: e.group)).toList();
    final capturedBasisMode = _basisMode;
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
            priorMeso: priorMeso,
            basisMode: capturedBasisMode,
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
    final selectedMeso =
        _mesocycles.where((m) => m.id == _basisMesoId).firstOrNull;
    final bool progressMode =
        _basisMesoId != null && _basisMode == 'progress';
    final int displayWeeks =
        progressMode && selectedMeso != null ? selectedMeso.numWeeks : _numWeeks;
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
                    if (_mesocycles.isNotEmpty) ...[
                      Text('Base on prior mesocycle (optional)',
                          style: SGText.body(13, color: p.textDim)),
                      const SizedBox(height: 8),
                      _MesoPicker(
                        mesocycles: _mesocycles,
                        selectedId: _basisMesoId,
                        palette: p,
                        onChanged: (id) => setState(() => _basisMesoId = id),
                      ),
                      if (_basisMesoId != null) ...[
                        const SizedBox(height: 12),
                        _BasisModePicker(
                          value: _basisMode,
                          palette: p,
                          onChanged: (v) => setState(() => _basisMode = v),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
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
                    IgnorePointer(
                      ignoring: progressMode,
                      child: Opacity(
                        opacity: progressMode ? 0.35 : 1.0,
                        child: SGStepper(
                          value: _trainingDays,
                          min: 1,
                          max: 7,
                          step: 1,
                          label: 'TRAINING DAYS / WEEK',
                          accentColor: p.accent,
                          onChanged: (v) =>
                              setState(() => _trainingDays = v.toInt()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    IgnorePointer(
                      ignoring: progressMode,
                      child: Opacity(
                        opacity: progressMode ? 0.35 : 1.0,
                        child: SGStepper(
                          value: displayWeeks,
                          min: 1,
                          max: 16,
                          step: 1,
                          label: 'WEEKS',
                          accentColor: p.accent,
                          onChanged: (v) =>
                              setState(() => _numWeeks = v.toInt()),
                        ),
                      ),
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

class _MesoPicker extends StatelessWidget {
  final List<Mesocycle> mesocycles;
  final String? selectedId;
  final SGPalette palette;
  final ValueChanged<String?> onChanged;

  const _MesoPicker({
    required this.mesocycles,
    required this.selectedId,
    required this.palette,
    required this.onChanged,
  });

  void _openSheet(BuildContext context) {
    final p = palette;
    showSGSheet(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prior mesocycle', style: SGText.display(18, color: p.text)),
          const SizedBox(height: 16),
          _OptionTile(
            label: 'None',
            sub: 'generate fresh',
            selected: selectedId == null,
            palette: p,
            onTap: () {
              onChanged(null);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 6),
          ...mesocycles.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _OptionTile(
                  label: m.name,
                  sub: '${m.numWeeks} weeks',
                  selected: selectedId == m.id,
                  palette: p,
                  onTap: () {
                    onChanged(m.id);
                    Navigator.pop(context);
                  },
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final selected = mesocycles.where((m) => m.id == selectedId).firstOrNull;
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.name ?? 'None',
                style: SGText.body(14,
                    color: selected != null ? p.text : p.textFaint),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              Text('${selected.numWeeks}w',
                  style: SGText.mono(10, color: p.textFaint)),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 16, color: p.textFaint),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final SGPalette palette;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.sub,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.10) : p.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.accent.withValues(alpha: 0.35) : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: SGText.body(14,
                          color: selected ? p.accent : p.text,
                          weight: selected
                              ? FontWeight.w600
                              : FontWeight.w400),
                      overflow: TextOverflow.ellipsis),
                  Text(sub, style: SGText.mono(10, color: p.textFaint)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: p.accent),
          ],
        ),
      ),
    );
  }
}

class _BasisModePicker extends StatelessWidget {
  final String value;
  final SGPalette palette;
  final ValueChanged<String> onChanged;

  const _BasisModePicker({
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  static const _options = [
    ('inspiration', 'Inspiration', 'adapts freely'),
    ('progress', 'Progress from', 'keeps structure'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: _options.map((opt) {
        final (mode, label, sub) = opt;
        final selected = value == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: mode == 'inspiration' ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                    style: SGText.body(13,
                        color: selected ? p.accent : p.text,
                        weight: selected
                            ? FontWeight.w600
                            : FontWeight.w400),
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
