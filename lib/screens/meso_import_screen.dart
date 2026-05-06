import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/queries.dart';
import '../models/meso_import_data.dart';
import '../providers.dart';
import '../services/llm_service.dart';
import '../services/model_service.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

enum _Phase { downloadingModel, loading, error, review, importing }

class MesoImportScreen extends ConsumerStatefulWidget {
  final String csvContent;

  const MesoImportScreen({super.key, required this.csvContent});

  @override
  ConsumerState<MesoImportScreen> createState() => _MesoImportScreenState();
}

class _MesoImportScreenState extends ConsumerState<MesoImportScreen> {
  _Phase _phase = _Phase.loading;
  MesoImportData? _data;
  String? _errorMessage;
  String? _rawLlmResponse;
  double _downloadProgress = 0;
  StreamSubscription<double>? _downloadSub;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _runLlm();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _runLlm() async {
    setState(() {
      _phase = _Phase.loading;
      _errorMessage = null;
      _rawLlmResponse = null;
    });

    try {
      if (!await ModelService.isDownloaded()) {
        setState(() {
          _phase = _Phase.downloadingModel;
          _downloadProgress = 0;
        });

        final completer = Completer<void>();
        _downloadSub = ModelService.download().listen(
          (progress) {
            if (mounted) setState(() => _downloadProgress = progress);
          },
          onError: (Object e) => completer.completeError(e),
          onDone: completer.complete,
          cancelOnError: true,
        );
        await completer.future;
        _downloadSub = null;

        if (!mounted) return;
        setState(() => _phase = _Phase.loading);
      }

      final data = await LlmService().interpretPlan(widget.csvContent);
      await _matchExercises(data);
      _nameController.text = data.name;
      setState(() {
        _data = data;
        _phase = _Phase.review;
      });
    } on LlmException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _rawLlmResponse = e.rawResponse;
        _phase = _Phase.error;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  void _cancelDownload() {
    _downloadSub?.cancel();
    _downloadSub = null;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _matchExercises(MesoImportData data) async {
    final db = ref.read(dbProvider);
    final existing = await db.allExercises();
    final names = existing.map((e) => e.name.toLowerCase()).toSet();

    for (final day in data.days) {
      for (final ex in day.exercises) {
        ex.isExistingInDb = names.contains(ex.name.toLowerCase());
      }
    }
  }

  Future<void> _import() async {
    final data = _data;
    if (data == null) return;
    data.name = _nameController.text.trim().isEmpty
        ? 'Imported Block'
        : _nameController.text.trim();

    setState(() => _phase = _Phase.importing);
    try {
      final db = ref.read(dbProvider);
      await db.importMesoFromPlan(data);
      ref.invalidate(activeMesoProvider);
      ref.invalidate(allMesosProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _phase = _Phase.error;
      });
    }
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
        title: Text('Import Plan', style: SGText.display(17, color: p.text)),
      ),
      body: switch (_phase) {
        _Phase.downloadingModel => _DownloadView(
            progress: _downloadProgress,
            palette: p,
            onCancel: _cancelDownload,
          ),
        _Phase.loading => _LoadingView(palette: p),
        _Phase.error => _ErrorView(
            message: _errorMessage ?? 'Unknown error',
            rawResponse: _rawLlmResponse,
            palette: p,
            onRetry: _runLlm,
          ),
        _Phase.importing => _LoadingView(palette: p, label: 'Saving…'),
        _Phase.review => _ReviewView(
            data: _data!,
            nameController: _nameController,
            palette: p,
            onImport: _import,
          ),
      },
    );
  }
}

// ── Download ──────────────────────────────────────────────────────────────────

class _DownloadView extends StatelessWidget {
  final double progress;
  final SGPalette palette;
  final VoidCallback onCancel;

  const _DownloadView({
    required this.progress,
    required this.palette,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final pct = (progress * 100).toStringAsFixed(0);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 48, color: p.accent),
                  const SizedBox(height: 24),
                  Text('Downloading model',
                      style: SGText.display(20, color: p.text)),
                  const SizedBox(height: 6),
                  Text('3.1 GB · one-time download',
                      style: SGText.body(13, color: p.textDim)),
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: p.border,
                      valueColor: AlwaysStoppedAnimation(p.accent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('$pct%', style: SGText.mono(12, color: p.textFaint)),
                  const SizedBox(height: 40),
                  SGButton.ghost(
                    label: 'Cancel',
                    color: p.textDim,
                    fullWidth: true,
                    onTap: onCancel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final SGPalette palette;
  final String label;

  const _LoadingView({required this.palette, this.label = 'Interpreting plan…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: palette.accent),
          const SizedBox(height: 16),
          Text(label, style: SGText.body(14, color: palette.textDim)),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final String? rawResponse;
  final SGPalette palette;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.rawResponse,
    required this.palette,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import failed', style: SGText.display(20, color: palette.text)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.warn.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: palette.warn.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Text(message,
                        style: SGText.mono(13, color: palette.warn)),
                  ),
                  if (rawResponse != null) ...[
                    const SizedBox(height: 12),
                    Text('Model output', style: SGText.mono(10, color: palette.textFaint)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border, width: 0.5),
                      ),
                      child: SingleChildScrollView(
                        child: Text(rawResponse!,
                            style: SGText.mono(11, color: palette.textDim)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  SGButton.solid(
                    label: 'Retry',
                    color: palette.accent,
                    fullWidth: true,
                    onTap: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Review ────────────────────────────────────────────────────────────────────

class _ReviewView extends StatelessWidget {
  final MesoImportData data;
  final TextEditingController nameController;
  final SGPalette palette;
  final VoidCallback onImport;

  const _ReviewView({
    required this.data,
    required this.nameController,
    required this.palette,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final newCount = data.days
        .expand((d) => d.exercises)
        .where((e) => !e.isExistingInDb)
        .length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TextField(
                controller: nameController,
                style: SGText.display(20, color: p.text),
                decoration: InputDecoration(
                  hintText: 'Plan name',
                  hintStyle: SGText.display(20, color: p.textFaint),
                  border: InputBorder.none,
                ),
              ),
              Row(
                children: [
                  SGChip('${data.numWeeks} WEEKS', tone: ChipTone.neutral),
                  const SizedBox(width: 8),
                  SGChip('${data.days.length} DAYS', tone: ChipTone.neutral),
                  if (newCount > 0) ...[
                    const SizedBox(width: 8),
                    SGChip('$newCount NEW EX', tone: ChipTone.warn),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              ...data.days.map((day) => _DayCard(day: day, palette: p)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _LegendDot(color: p.success),
                  const SizedBox(width: 6),
                  Text('Existing exercise', style: SGText.mono(10, color: p.textFaint)),
                  const SizedBox(width: 16),
                  _LegendDot(color: p.warn),
                  const SizedBox(width: 6),
                  Text('Will be created', style: SGText.mono(10, color: p.textFaint)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
          child: SGButton.solid(
            label: 'Import Block',
            color: palette.accent,
            fullWidth: true,
            onTap: onImport,
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final ImportDay day;
  final SGPalette palette;

  const _DayCard({required this.day, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              day.label.isEmpty ? 'Day ${day.dayIdx + 1}' : day.label,
              style: SGText.display(14, color: p.text, weight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          ...day.exercises.map((ex) => _ExerciseRow(ex: ex, palette: p)),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ImportExercise ex;
  final SGPalette palette;

  const _ExerciseRow({required this.ex, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final t = ex.targetForWeek(0);
    final color = ex.isExistingInDb ? p.success : p.warn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ex.name, style: SGText.body(13, color: p.text)),
          ),
          Text(
            '${t.sets}×${t.reps}  @${t.rir}RIR',
            style: SGText.mono(11, color: p.textDim),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
