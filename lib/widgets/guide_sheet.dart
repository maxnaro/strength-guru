import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

class GuideSheet extends StatefulWidget {
  final String exerciseName;

  const GuideSheet({super.key, required this.exerciseName});

  static Future<void> show(BuildContext context, String exerciseName) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GuideSheet(exerciseName: exerciseName),
    );
  }

  @override
  State<GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<GuideSheet> {
  late YoutubePlayerController _controller;
  bool _isLoading = true;
  String? _error;
  String? _videoId;
  final _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final results = await _yt.search.search('${widget.exerciseName} exercise form tutorial');
      if (results.isEmpty) {
        setState(() {
          _error = 'No videos found for "${widget.exerciseName}"';
          _isLoading = false;
        });
        return;
      }

      _videoId = results.first.id.value;
      _controller = YoutubePlayerController.fromVideoId(
        videoId: _videoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: false, // Fullscreen in a bottom sheet is buggy/heavy
          mute: false,
          showControls: true,
          // Optimization: Related videos will only come from the same channel
          strictRelatedVideos: true,
          // Fix for Error 152-4: Still use the nocookie origin for verification
          origin: 'https://www.youtube-nocookie.com',
          // Lightweight User Agent: Mobile Safari is generally more efficient than a full Chrome Desktop UA
          userAgent:
              'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
        ),
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load guide: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchYouTube() async {
    final String urlString;
    if (_videoId != null) {
      urlString = 'https://www.youtube.com/watch?v=$_videoId';
    } else {
      urlString =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent("${widget.exerciseName} exercise form tutorial")}';
    }

    final url = Uri.parse(urlString);

    try {
      // mode: LaunchMode.externalApplication is usually best for YouTube to trigger the app,
      // but on emulators without the app, platformDefault is more reliable.
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        // Fallback to in-app browser if external app fails (common on emulators)
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open YouTube: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _yt.close();
    if (!_isLoading && _error == null) {
      _controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(SGRadius.card)),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FORM GUIDE', style: SGText.mono(10, color: p.textFaint)),
                    Text(widget.exerciseName, style: SGText.body(18, color: p.text).copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: p.textDim),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(SGRadius.card),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, style: SGText.body(14, color: p.warn), textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  SGButton.soft(
                                    label: 'Open in YouTube',
                                    onTap: _launchYouTube,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : YoutubePlayer(controller: _controller),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error == null && !_isLoading) ...[
            SGButton.soft(
              label: 'Watch on YouTube',
              trailingIcon: Icon(Icons.open_in_new, size: 14, color: p.accent),
              onTap: _launchYouTube,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Powered by YouTube. Always prioritize safety and listen to your body.',
            style: SGText.body(12, color: p.textFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
