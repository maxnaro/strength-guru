import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';

class GuideSheet extends StatefulWidget {
  final String exerciseName;
  const GuideSheet({super.key, required this.exerciseName});
  static Future<void> show(BuildContext context, String exerciseName) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => GuideSheet(exerciseName: exerciseName),
      );
  @override
  State<GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<GuideSheet> {
  late final Future<Map<String, dynamic>> videos = appApi.json(
    'GET',
    'guides?exercise=${Uri.encodeComponent(widget.exerciseName)}',
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.exerciseName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: videos,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Text(
                  'Could not load guides. You can still search YouTube.',
                );
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return Column(
                children: [
                  for (final video in snapshot.data!['videos'] as List)
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(video['title'] as String),
                      onTap: () => launchUrl(
                        appApi.origin.resolve('/guide/${video['id']}'),
                        webOnlyWindowName: '_blank',
                      ),
                    ),
                ],
              );
            },
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.https('www.youtube.com', '/results', {
                'search_query': '${widget.exerciseName} exercise form tutorial',
              }),
              webOnlyWindowName: '_blank',
            ),
            child: const Text('Search YouTube'),
          ),
        ],
      ),
    ),
  );
}
