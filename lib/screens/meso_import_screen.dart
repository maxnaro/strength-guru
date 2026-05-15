import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:string_similarity/string_similarity.dart';

import '../db/queries.dart';
import '../models/meso_import_data.dart';
import '../providers.dart';
import '../services/llm_service.dart';
import '../services/model_service.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/import_week_edit_sheet.dart';
import '../widgets/timeline_cell.dart';

enum _Phase {
  configuration,
  downloadingModel,
  loading,
  error,
  review,
  importing
}

class MesoImportScreen extends ConsumerStatefulWidget {
  final String? csvContent;
  final Future<MesoImportData> Function(
    void Function(int, int)? onProgress,
    void Function(String reasoningDelta) onReasoning,
  )? dataProducer;

  const MesoImportScreen({
    super.key,
    this.csvContent,
    this.dataProducer,
  }) : assert(
          (csvContent != null) != (dataProducer != null),
          'Provide exactly one of csvContent or dataProducer',
        );

  @override
  ConsumerState<MesoImportScreen> createState() => _MesoImportScreenState();
}

class _MesoImportScreenState extends ConsumerState<MesoImportScreen> {
  _Phase _phase = _Phase.loading; // Will be set to configuration in initState
  MesoImportData? _data;
  String? _errorMessage;
  String? _rawLlmResponse;
  double _downloadProgress = 0;
  String _loadingLabel = 'Interpreting plan…';
  String _reasoning = '';
  StreamSubscription<double>? _downloadSub;
  final _nameController = TextEditingController();
  final _apiUrlController = TextEditingController();
  bool _useExternalApi = true;

  @override
  void initState() {
    super.initState();
    if (widget.dataProducer != null) {
      _runProducer();
    } else {
      _loadConfigAndStart();
    }
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _nameController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigAndStart() async {
    final db = ref.read(dbProvider);
    final savedUrl = await db.getSetting('llm_api_url');
    final useExternal = await db.getSetting('llm_use_external');

    if (mounted) {
      setState(() {
        _apiUrlController.text = savedUrl ?? LlmService.defaultUrl;
        _useExternalApi = useExternal == 'true' || useExternal == null;
        _phase = _Phase.configuration;
      });
    }
  }

  Future<void> _startProcessing() async {
    final db = ref.read(dbProvider);
    await db.setSetting('llm_api_url', _apiUrlController.text.trim());
    await db.setSetting('llm_use_external', _useExternalApi.toString());

    _runLlm();
  }

  Future<void> _runProducer() async {
    setState(() {
      _phase = _Phase.loading;
      _errorMessage = null;
      _rawLlmResponse = null;
      _loadingLabel = 'Generating program…';
      _reasoning = '';
    });
    try {
      final data = await widget.dataProducer!(
        (done, total) {
          if (mounted) {
            setState(() => _loadingLabel = 'Generating day $done/$total…');
          }
        },
        (delta) {
          if (mounted) {
            setState(() {
              if (delta.isEmpty) {
                _reasoning = '';
              } else {
                _reasoning += delta;
              }
            });
          }
        },
      );
      await _handleData(data,
          emptyMessage:
              'No training days were generated. Refine your description and try again.');
    } on LlmException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _rawLlmResponse = e.rawResponse;
          _phase = _Phase.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _phase = _Phase.error;
        });
      }
    }
  }

  Future<void> _handleData(MesoImportData data,
      {String emptyMessage =
          'No training days could be parsed. Check the format and try again.'}) async {
    if (data.days.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = emptyMessage;
          _phase = _Phase.error;
        });
      }
      return;
    }
    await _matchExercises(data);
    if (mounted) {
      _nameController.text = data.name;
      setState(() {
        _data = data;
        _phase = _Phase.review;
      });
    }
  }

  Future<void> _runLlm() async {
    setState(() {
      _phase = _Phase.loading;
      _errorMessage = null;
      _rawLlmResponse = null;
      _loadingLabel = 'Interpreting plan…';
    });

    try {
      if (!_useExternalApi && !await ModelService.isDownloaded()) {
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

      final cleanedCsv = widget.csvContent!
          .split('\n')
          .map((line) => line.trim())
          .where((line) =>
              line.isNotEmpty && line.replaceAll(',', '').trim().isNotEmpty)
          .map((line) => line.replaceAll('~', '').replaceAll('approx', ''))
          .join('\n');

      final data = await LlmService().interpretPlan(
        cleanedCsv,
        apiUrl: _useExternalApi ? _apiUrlController.text.trim() : null,
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _loadingLabel = 'Interpreting day $done/$total…');
          }
        },
      );
      await _handleData(data,
          emptyMessage:
              'No training days could be parsed from the CSV. Check the format and try again.');
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
    ModelService.cancel();
    _downloadSub?.cancel();
    _downloadSub = null;
    if (mounted) setState(() => _phase = _Phase.configuration);
  }

  Future<void> _matchExercises(MesoImportData data) async {
    final db = ref.read(dbProvider);
    final existing = await db.allExercises();
    final existingNames = existing.map((e) => e.name).toList();

    if (existingNames.isEmpty) return;

    for (final day in data.days) {
      for (final ex in day.exercises) {
        final match = ex.name.bestMatch(existingNames);
        if ((match.bestMatch.rating ?? 0) > 0.75) {
          ex.name = match.bestMatch.target!;
          ex.isExistingInDb = true;
        } else {
          ex.isExistingInDb = false;
        }
      }
    }
  }

  Future<void> _import() async {
    final data = _data;
    if (data == null) return;
    data.name = _nameController.text.trim().isEmpty
        ? 'Imported Block'
        : _nameController.text.trim();

    // Fix up day indices based on current order
    for (int i = 0; i < data.days.length; i++) {
      data.days[i].dayIdx = i;
    }

    setState(() => _phase = _Phase.importing);
    try {
      final db = ref.read(dbProvider);
      await db.importMesoFromPlan(data);
      ref.invalidate(activeMesoProvider);
      ref.invalidate(allMesosProvider);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ref.read(tabIndexProvider.notifier).state = 2;
      }
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
        title: Text(
          widget.dataProducer != null ? 'Generate Program' : 'Import Plan',
          style: SGText.display(17, color: p.text),
        ),
      ),
      body: switch (_phase) {
        _Phase.configuration => _ConfigView(
            apiUrlController: _apiUrlController,
            useExternalApi: _useExternalApi,
            palette: p,
            onToggleApi: (val) => setState(() => _useExternalApi = val),
            onStart: _startProcessing,
          ),
        _Phase.downloadingModel => _DownloadView(
            progress: _downloadProgress,
            palette: p,
            onCancel: _cancelDownload,
          ),
        _Phase.loading =>
          _LoadingView(palette: p, label: _loadingLabel, reasoning: _reasoning),
        _Phase.error => _ErrorView(
            message: _errorMessage ?? 'Unknown error',
            rawResponse: _rawLlmResponse,
            palette: p,
            onRetry: widget.dataProducer != null ? _runProducer : _runLlm,
          ),
        _Phase.importing => _LoadingView(palette: p, label: 'Saving…'),
        _Phase.review => _ReviewView(
            data: _data!,
            nameController: _nameController,
            palette: p,
            onChanged: () => setState(() {}),
            onImport: _import,
          ),
      },
    );
  }
}

// ── Configuration ─────────────────────────────────────────────────────────────

class _ConfigView extends StatelessWidget {
  final TextEditingController apiUrlController;
  final bool useExternalApi;
  final SGPalette palette;
  final ValueChanged<bool> onToggleApi;
  final VoidCallback onStart;

  const _ConfigView({
    required this.apiUrlController,
    required this.useExternalApi,
    required this.palette,
    required this.onToggleApi,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
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
                  Text('LLM Configuration',
                      style: SGText.display(20, color: p.text)),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to interpret this CSV file. Using an external API (like LM Studio) is much faster than on-device processing.',
                    style: SGText.body(14, color: p.textDim),
                  ),
                  const SizedBox(height: 32),
                  _ConfigOption(
                    title: 'External API (OpenAI Compatible)',
                    subtitle: 'Fastest. Requires LM Studio or similar running.',
                    icon: Icons.api_rounded,
                    selected: useExternalApi,
                    palette: p,
                    onTap: () => onToggleApi(true),
                  ),
                  if (useExternalApi) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: apiUrlController,
                        style: SGText.mono(13, color: p.text),
                        decoration: InputDecoration(
                          hintText: 'http://...',
                          hintStyle: SGText.mono(13, color: p.textFaint),
                          border: InputBorder.none,
                          labelText: 'Endpoint URL',
                          labelStyle: SGText.body(11, color: p.textFaint),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ConfigOption(
                    title: 'On-Device LLM',
                    subtitle: 'Private and offline. Slower (2-3 mins).',
                    icon: Icons.phonelink_setup_rounded,
                    selected: !useExternalApi,
                    palette: p,
                    onTap: () => onToggleApi(false),
                  ),
                  const Spacer(),
                  SGButton.solid(
                    label: 'Start Interpretation',
                    color: p.accent,
                    fullWidth: true,
                    onTap: onStart,
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

class _ConfigOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final SGPalette palette;
  final VoidCallback onTap;

  const _ConfigOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.05) : p.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? p.accent : p.textDim, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: SGText.body(15,
                          color: selected ? p.text : p.textDim,
                          weight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                  Text(subtitle, style: SGText.body(12, color: p.textFaint)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: p.accent, size: 20),
          ],
        ),
      ),
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
                  Text('2.3 GB · one-time download',
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
  final String reasoning;

  const _LoadingView({
    required this.palette,
    this.label = 'Interpreting plan…',
    this.reasoning = '',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: palette.accent),
            const SizedBox(height: 24),
            Text(label, style: SGText.display(20, color: palette.text)),
            const SizedBox(height: 8),
            Text(
              'Please stay on this screen.\nClosing the app will stop the interpretation.',
              textAlign: TextAlign.center,
              style: SGText.body(14, color: palette.textDim),
            ),
            if (reasoning.isNotEmpty) ...[
              const SizedBox(height: 24),
              _ReasoningBox(reasoning: reasoning, palette: palette),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasoningBox extends StatefulWidget {
  final String reasoning;
  final SGPalette palette;

  const _ReasoningBox({required this.reasoning, required this.palette});

  @override
  State<_ReasoningBox> createState() => _ReasoningBoxState();
}

class _ReasoningBoxState extends State<_ReasoningBox> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_ReasoningBox old) {
    super.didUpdateWidget(old);
    if (widget.reasoning != old.reasoning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          collapsedIconColor: p.textFaint,
          iconColor: p.textFaint,
          tilePadding: EdgeInsets.zero,
          title: Text('Thinking', style: SGText.mono(10, color: p.textFaint)),
          children: [
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border, width: 0.5),
              ),
              child: Markdown(
                controller: _scrollController,
                data: widget.reasoning,
                padding: EdgeInsets.zero,
                styleSheet: MarkdownStyleSheet(
                  p: SGText.body(12, color: p.textDim),
                  code: SGText.mono(11, color: p.textDim),
                  h1: SGText.display(14, color: p.text),
                  h2: SGText.display(13, color: p.text),
                  h3: SGText.body(12, color: p.text, weight: FontWeight.w600),
                  listBullet: SGText.body(12, color: p.textDim),
                ),
              ),
            ),
          ],
        ));
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
                  Text('Import failed',
                      style: SGText.display(20, color: palette.text)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.warn.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: palette.warn.withValues(alpha: 0.3),
                          width: 0.5),
                    ),
                    child: Text(message,
                        style: SGText.mono(13, color: palette.warn)),
                  ),
                  if (rawResponse != null) ...[
                    const SizedBox(height: 12),
                    Text('Model output',
                        style: SGText.mono(10, color: palette.textFaint)),
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
  final VoidCallback onChanged;
  final VoidCallback onImport;

  const _ReviewView({
    required this.data,
    required this.nameController,
    required this.palette,
    required this.onChanged,
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
        // Plan name + stats header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: p.inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: nameController,
                  style: SGText.display(20, color: p.text),
                  decoration: InputDecoration(
                    hintText: 'Plan name',
                    hintStyle: SGText.display(20, color: p.textFaint),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SGChip('${data.numWeeks} WEEKS', tone: ChipTone.neutral),
                  SGChip('${data.days.length} DAYS', tone: ChipTone.neutral),
                  if (newCount > 0)
                    SGChip('$newCount NEW EX', tone: ChipTone.warn),
                  if (data.skippedDayLabels.isNotEmpty)
                    SGChip(
                      '${data.skippedDayLabels.length} DAYS SKIPPED',
                      tone: ChipTone.warn,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // Timeline grid + footer
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImportTimelineView(
                  data: data,
                  palette: p,
                  onChanged: onChanged,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (data.days.length < 7)
                        SGButton.ghost(
                          label: 'Add Rest Day',
                          leadingIcon:
                              Icon(Icons.add, color: p.accent, size: 20),
                          color: p.accent,
                          onTap: () {
                            data.days.add(ImportDay(
                              dayIdx: data.days.length,
                              label: 'Rest Day',
                              exercises: [],
                            ));
                            onChanged();
                          },
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _LegendDot(color: p.success),
                          const SizedBox(width: 6),
                          Text('Existing exercise',
                              style: SGText.mono(10, color: p.textFaint)),
                          const SizedBox(width: 16),
                          _LegendDot(color: p.warn),
                          const SizedBox(width: 6),
                          Text('Will be created',
                              style: SGText.mono(10, color: p.textFaint)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Import button
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 20),
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

class _ImportTimelineView extends StatelessWidget {
  final MesoImportData data;
  final SGPalette palette;
  final VoidCallback onChanged;

  const _ImportTimelineView({
    required this.data,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final brightness = Theme.of(context).brightness;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: kTimelineNameColW + data.numWeeks * (kTimelineCellW + 2) + 60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header row
            Row(
              children: [
                const SizedBox(width: kTimelineNameColW),
                ...List.generate(
                  data.numWeeks,
                  (w) => Container(
                    width: kTimelineCellW,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    alignment: Alignment.center,
                    child: Text('W${w + 1}',
                        style: SGText.mono(9, color: p.textDim)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Day sections — drag-reorderable
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx -= 1;
                final d = data.days.removeAt(oldIdx);
                data.days.insert(newIdx, d);
                onChanged();
              },
              children: [
                for (int i = 0; i < data.days.length; i++)
                  _ImportDaySection(
                    key: ValueKey(data.days[i]),
                    day: data.days[i],
                    dayIndex: i,
                    numWeeks: data.numWeeks,
                    palette: p,
                    brightness: brightness,
                    onChanged: onChanged,
                    onDelete: () {
                      data.days.removeAt(i);
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportDaySection extends StatefulWidget {
  final ImportDay day;
  final int dayIndex;
  final int numWeeks;
  final SGPalette palette;
  final Brightness brightness;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ImportDaySection({
    super.key,
    required this.day,
    required this.dayIndex,
    required this.numWeeks,
    required this.palette,
    required this.brightness,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ImportDaySection> createState() => _ImportDaySectionState();
}

class _ImportDaySectionState extends State<_ImportDaySection> {
  late TextEditingController _labelController;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.day.label);
  }

  @override
  void didUpdateWidget(_ImportDaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      _labelController.text = widget.day.label;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final group = widget.day.exercises.isEmpty
        ? MuscleGroup.rest
        : MuscleGroupX.fromString(widget.day.exercises.first.muscleGroup);
    final exCount = widget.day.exercises.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: widget.dayIndex,
                child: Icon(Icons.drag_indicator, size: 16, color: p.textFaint),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: group.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _labelController,
                    onChanged: (val) => widget.day.label = val,
                    style: SGText.display(13, color: p.text),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 16,
                  color: p.textFaint,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _collapsed = !_collapsed),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 14, color: p.textFaint),
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDelete,
              ),
              if (_collapsed) ...[
                const SizedBox(width: 8),
                Text(
                  exCount == 0 ? 'Rest day' : '$exCount exercises',
                  style: SGText.mono(10, color: p.textFaint),
                ),
              ],
            ],
          ),
          if (!_collapsed) ...[
            const SizedBox(height: 2),
            // Exercise rows
            ...widget.day.exercises.map(
              (ex) => _ImportTimelineRow(
                ex: ex,
                group: MuscleGroupX.fromString(ex.muscleGroup),
                numWeeks: widget.numWeeks,
                palette: p,
                brightness: widget.brightness,
                onChanged: widget.onChanged,
                onDelete: () {
                  widget.day.exercises.remove(ex);
                  widget.onChanged();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportTimelineRow extends StatelessWidget {
  final ImportExercise ex;
  final MuscleGroup group;
  final int numWeeks;
  final SGPalette palette;
  final Brightness brightness;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ImportTimelineRow({
    required this.ex,
    required this.group,
    required this.numWeeks,
    required this.palette,
    required this.brightness,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Name cell — tap to swap exercise
          GestureDetector(
            onTap: () => showSGSheet(
              context,
              maxHeightFraction: 0.8,
              child: ExercisePicker(
                defaultGroup: group,
                onSelected: (picked) {
                  ex.name = picked.name;
                  ex.muscleGroup = picked.group;
                  ex.isExistingInDb = true;
                  onChanged();
                  Navigator.pop(context);
                },
              ),
            ),
            child: SizedBox(
              width: kTimelineNameColW,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ex.isExistingInDb ? p.success : p.warn,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 112,
                    child: Text(
                      ex.name,
                      style: SGText.body(12,
                          weight: FontWeight.w500, color: p.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Week cells
          ...List.generate(numWeeks, (w) {
            final t = ex.targetForWeek(w);
            return TimelineCell(
              reps: t.reps,
              rir: t.rir,
              bgColor: group.tint(brightness).withValues(alpha: 0.5),
              borderColor: p.border,
              borderWidth: 0.5,
              palette: p,
              onTap: () => showSGSheet(
                context,
                isScrollControlled: true,
                maxHeightFraction: 0.9,
                child: ImportWeekEditSheet(
                  ex: ex,
                  weekIdx: w,
                  numWeeks: numWeeks,
                  group: group,
                  onChanged: onChanged,
                ),
              ),
            );
          }),
          // Delete
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: p.textFaint),
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
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
