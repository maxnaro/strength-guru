import 'package:flutter/material.dart';
import 'package:strength_guru_core/sync/storage.dart';
import '../screens/meso_import_screen.dart';
import '../services/llm_service.dart';
import '../services/api.dart';

class AiJobsSheet extends StatefulWidget {
  const AiJobsSheet({super.key});
  @override
  State<AiJobsSheet> createState() => _AiJobsSheetState();
}

class _AiJobsSheetState extends State<AiJobsSheet> {
  Future<List<Map<String, dynamic>>> load() async {
    final db = LlmService.database;
    if (db == null) return [];
    final ids = (await readMeta(db, 'ai_jobs') ?? '')
        .split(',')
        .where((s) => s.isNotEmpty);
    return Future.wait(
      ids.map((id) async {
        try {
          return await appApi.json('GET', 'jobs/$id');
        } catch (_) {
          return <String, dynamic>{
            'id': id,
            'state': 'unavailable',
            'kind': 'AI job',
          };
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('AI jobs', style: TextStyle(fontSize: 20)),
                ),
                IconButton(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder(
                future: load(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('${snapshot.error}');
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.isEmpty)
                    return const Center(
                      child: Text('Your AI jobs will appear here.'),
                    );
                  return ListView(
                    children: [
                      for (final job in snapshot.data!)
                        ListTile(
                          title: Text('${job['kind']} · ${job['state']}'),
                          subtitle: Text(job['progress'] as String? ?? ''),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MesoImportScreen(
                                  dataProducer: (progress, status) =>
                                      LlmService().resumeJob(
                                        job['id'] as String,
                                        onProgress: progress,
                                        onReasoning: status,
                                      ),
                                ),
                              ),
                            );
                          },
                          trailing: ['queued', 'running'].contains(job['state'])
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_outlined),
                                  onPressed: () async {
                                    await appApi.json(
                                      'DELETE',
                                      'jobs/${job['id']}',
                                    );
                                    if (mounted) setState(() {});
                                  },
                                )
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
