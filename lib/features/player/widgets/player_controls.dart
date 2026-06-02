import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/api/hdrezka_stream.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/focusable_card.dart';

class PlayerControls extends StatefulWidget {
  final Player player;
  final HdRezkaStream stream;
  final VoidCallback onClose;

  const PlayerControls({
    super.key,
    required this.player,
    required this.stream,
    required this.onClose,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  Timer? _hideTimer;
  bool _visible = true;
  bool _showQualityPicker = false;

  Duration _position  = Duration.zero;
  Duration _duration  = Duration.zero;
  bool     _playing   = false;
  String?  _selectedQuality;

  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<bool>     _playSub;

  @override
  void initState() {
    super.initState();
    _posSub  = widget.player.stream.position.listen((p) => setState(() => _position = p));
    _durSub  = widget.player.stream.duration.listen((d) => setState(() => _duration = d));
    _playSub = widget.player.stream.playing.listen((p) => setState(() => _playing = p));
    _selectedQuality = widget.stream.sortedResolutions.firstOrNull;
    _resetHideTimer();
  }

  @override
  void dispose() {
    _posSub.cancel();
    _durSub.cancel();
    _playSub.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _showControls() {
    setState(() => _visible = true);
    _resetHideTimer();
  }

  void _seek(Duration offset) {
    final raw = _position + offset;
    final newPos = raw < Duration.zero ? Duration.zero : (raw > _duration ? _duration : raw);
    widget.player.seek(newPos);
    _showControls();
  }

  void _changeQuality(String quality) {
    final urls = widget.stream.call(quality);
    if (urls.isNotEmpty) {
      widget.player.open(Media(urls.first));
      widget.player.seek(_position);
    }
    setState(() {
      _selectedQuality = quality;
      _showQualityPicker = false;
    });
    _resetHideTimer();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          _showControls();
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.mediaRewind) {
            _seek(const Duration(seconds: -10));
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.mediaFastForward) {
            _seek(const Duration(seconds: 10));
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
            widget.player.playOrPause();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            widget.onClose();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Stack(
            children: [
              // Dark gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(180),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withAlpha(200),
                      ],
                      stops: const [0, 0.2, 0.7, 1],
                    ),
                  ),
                ),
              ),

              // Top bar: back button + title
              Positioned(
                top: TvSafe.v, left: TvSafe.h, right: TvSafe.h,
                child: Row(
                  children: [
                    FocusableCard(
                      onSelect: widget.onClose,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.stream.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Quality picker button
                    FocusableCard(
                      onSelect: () => setState(() => _showQualityPicker = !_showQualityPicker),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withAlpha(200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _selectedQuality ?? 'HD',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quality picker overlay
              if (_showQualityPicker)
                Positioned(
                  top: TvSafe.v + 60, right: TvSafe.h,
                  child: _QualityPicker(
                    resolutions: widget.stream.sortedResolutions,
                    selected: _selectedQuality,
                    onSelect: _changeQuality,
                  ),
                ),

              // Bottom controls
              Positioned(
                bottom: TvSafe.v, left: TvSafe.h, right: TvSafe.h,
                child: Column(
                  children: [
                    // Progress bar
                    _ProgressBar(position: _position, duration: _duration, player: widget.player),
                    const SizedBox(height: 12),

                    // Control row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Time
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        const SizedBox(width: 16),

                        // Rewind 10s
                        FocusableCard(
                          onSelect: () => _seek(const Duration(seconds: -10)),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.replay_10_rounded, color: Colors.white, size: 32),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Play / Pause
                        FocusableCard(
                          autofocus: true,
                          onSelect: widget.player.playOrPause,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Forward 10s
                        FocusableCard(
                          onSelect: () => _seek(const Duration(seconds: 10)),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.forward_10_rounded, color: Colors.white, size: 32),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Duration
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Player player;

  const _ProgressBar({required this.position, required this.duration, required this.player});

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
      ),
      child: Slider(
        value: progress,
        onChanged: (v) {
          final ms = (v * duration.inMilliseconds).round();
          player.seek(Duration(milliseconds: ms));
        },
      ),
    );
  }
}

class _QualityPicker extends StatelessWidget {
  final List<String> resolutions;
  final String? selected;
  final void Function(String) onSelect;

  const _QualityPicker({required this.resolutions, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: resolutions.map((r) => FocusableCard(
          onSelect: () => onSelect(r),
          child: Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: r == selected ? AppColors.accent.withAlpha(40) : Colors.transparent,
            child: Text(
              r,
              style: TextStyle(
                color: r == selected ? AppColors.accent : Colors.white,
                fontSize: 16,
                fontWeight: r == selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}
