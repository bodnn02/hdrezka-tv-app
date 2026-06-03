import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/api/hdrezka_stream.dart';
import '../../core/services/watch_history_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/content_provider.dart';
import '../../providers/stream_provider.dart';
import 'widgets/player_controls.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String contentUrl;
  final int? season;
  final int? episode;
  final int? translatorId;

  const PlayerScreen({
    super.key,
    required this.contentUrl,
    this.season,
    this.episode,
    this.translatorId,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  bool _opened = false;

  // Cached stream metadata for history recording
  HdRezkaStream? _currentStream;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    // Hide system bars only during playback; restored in dispose.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _player.stop();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _saveProgress() {
    final stream = _currentStream;
    if (stream == null) return;
    final position = _player.state.position;
    final duration = _player.state.duration;
    // Don't save if we watched less than 5 seconds
    if (position.inSeconds < 5) return;

    ref.read(watchHistoryProvider.notifier).record(
      url: widget.contentUrl,
      title: stream.name,
      thumbnail: '',  // filled below via content provider if cached
      season: widget.season,
      episode: widget.episode,
      translatorId: widget.translatorId,
      position: position,
      total: duration.inSeconds > 0 ? duration : null,
    );
  }

  void _openStream(HdRezkaStream stream) {
    if (_opened) return;
    _opened = true;
    _currentStream = stream;

    final resolution = stream.sortedResolutions.firstOrNull;
    if (resolution == null) return;
    final url = stream.bestUrl(resolution);
    if (url == null) return;
    _player.open(Media(url));

    for (final entry in stream.subtitles.subtitles.entries) {
      final link = entry.value['link'];
      if (link != null && link.isNotEmpty) {
        _player.setSubtitleTrack(SubtitleTrack.uri(
          link,
          title: entry.value['title'],
          language: entry.key,
        ));
      }
    }

    // Resume from saved position
    final saved = ref.read(watchHistoryProvider.notifier)
        .getEntry(widget.contentUrl, season: widget.season, episode: widget.episode);
    if (saved != null && saved.position.inSeconds > 5) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _player.seek(saved.position);
      });
    }
  }

  void _close() {
    _saveProgress();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final params = StreamParams(
      url: widget.contentUrl,
      season: widget.season,
      episode: widget.episode,
      translatorId: widget.translatorId,
    );
    final streamAsync = ref.watch(streamProvider(params));

    // Also try to get the thumbnail from content provider for history
    final contentAsync = ref.watch(contentProvider(widget.contentUrl));

    return Scaffold(
      backgroundColor: Colors.black,
      body: streamAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text('Загрузка видео...', style: TextStyle(color: Colors.white70, fontSize: 18)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text('Ошибка: $e', style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
        data: (stream) {
          _openStream(stream);

          // Enrich history with thumbnail once content loads
          contentAsync.whenData((api) async {
            try {
              final thumb = await api.thumbnail;
              if (thumb.isNotEmpty) {
                ref.read(watchHistoryProvider.notifier).record(
                  url: widget.contentUrl,
                  title: stream.name,
                  thumbnail: thumb,
                  season: widget.season,
                  episode: widget.episode,
                  translatorId: widget.translatorId,
                  position: _player.state.position,
                  total: _player.state.duration.inSeconds > 0 ? _player.state.duration : null,
                );
              }
            } catch (_) {}
          });

          return Stack(
            fit: StackFit.expand,
            children: [
              Video(controller: _videoController),
              PlayerControls(
                player: _player,
                stream: stream,
                onClose: _close,
              ),
            ],
          );
        },
      ),
    );
  }
}
