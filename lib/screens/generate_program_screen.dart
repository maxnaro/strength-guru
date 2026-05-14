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

class _GenerateProgramScreenState extends ConsumerState<GenerateProgramScreen> {
  final _descriptionController = TextEditingController();
  final _apiUrlController = TextEditingController();
  int _numWeeks = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _apiUrlController.dispose();
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

    if (!mounted) return;
    final weeks = _numWeeks;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MesoImportScreen(
          dataProducer: (onProgress) => LlmService().interpretDescription(
            desc,
            weeks,
            apiUrl: url,
            onProgress: onProgress,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Duration', style: SGText.body(13, color: p.textDim)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: _numWeeks > 1 ? p.accent : p.textFaint),
                          onPressed: _numWeeks > 1
                              ? () => setState(() => _numWeeks--)
                              : null,
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '$_numWeeks ${_numWeeks == 1 ? 'week' : 'weeks'}',
                            textAlign: TextAlign.center,
                            style: SGText.display(16, color: p.text),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: _numWeeks < 16 ? p.accent : p.textFaint),
                          onPressed: _numWeeks < 16
                              ? () => setState(() => _numWeeks++)
                              : null,
                        ),
                      ],
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
                          labelText: 'OpenAI-compatible endpoint',
                          labelStyle: SGText.body(11, color: p.textFaint),
                        ),
                      ),
                    ),
                    const Spacer(),
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
