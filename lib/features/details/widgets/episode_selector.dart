import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/hdrezka_types.dart';
import '../../../core/theme/app_theme.dart';

class EpisodeSelector extends StatefulWidget {
  final List<SeasonInfo> seasons;
  final void Function(int season, int episode, int translatorId) onSelect;

  const EpisodeSelector({
    super.key,
    required this.seasons,
    required this.onSelect,
  });

  @override
  State<EpisodeSelector> createState() => _EpisodeSelectorState();
}

class _EpisodeSelectorState extends State<EpisodeSelector> {
  late int _selectedSeason;
  int? _selectedEpisode;

  @override
  void initState() {
    super.initState();
    // Use the actual first season number, never hardcode 1
    _selectedSeason = widget.seasons.isNotEmpty ? widget.seasons.first.season : 1;
    // Auto-select first episode so Play works immediately
    final firstEp = _currentEpisodes.firstOrNull;
    if (firstEp != null) {
      _selectedEpisode = firstEp.episode;
      final trId = firstEp.translations.firstOrNull?.id;
      if (trId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSelect(_selectedSeason, firstEp.episode, trId);
        });
      }
    }
  }

  List<EpisodeInfo> get _currentEpisodes {
    if (widget.seasons.isEmpty) return [];
    return widget.seasons
        .firstWhere(
          (s) => s.season == _selectedSeason,
          orElse: () => widget.seasons.first,
        )
        .episodes;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seasons row
        if (widget.seasons.length > 1) ...[
          Text('Сезон', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 10),
          FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.seasons.map((s) => _Chip(
                  label: s.seasonText.isEmpty ? 'Сезон ${s.season}' : s.seasonText,
                  isSelected: _selectedSeason == s.season,
                  onSelect: () {
                    setState(() {
                      _selectedSeason = s.season;
                      _selectedEpisode = null;
                    });
                    // Auto-select first episode of the new season
                    final firstEp = _currentEpisodes.firstOrNull;
                    if (firstEp != null) {
                      setState(() => _selectedEpisode = firstEp.episode);
                      final trId = firstEp.translations.firstOrNull?.id;
                      if (trId != null) widget.onSelect(_selectedSeason, firstEp.episode, trId);
                    }
                  },
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Episodes row
        Text('Эпизод', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onSurfaceMuted)),
        const SizedBox(height: 10),
        FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _currentEpisodes.map((ep) => _Chip(
                label: ep.episodeText.isEmpty ? '${ep.episode}' : ep.episodeText,
                isSelected: _selectedEpisode == ep.episode,
                onSelect: () {
                  setState(() => _selectedEpisode = ep.episode);
                  final trId = ep.translations.firstOrNull?.id;
                  if (trId != null) widget.onSelect(_selectedSeason, ep.episode, trId);
                },
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelect;

  const _Chip({required this.label, required this.isSelected, required this.onSelect});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onSelect();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withAlpha(_focused ? 45 : 22),
                        Colors.white.withAlpha(_focused ? 18 : 8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: _focused
                    ? AppColors.glassBorderFocus
                    : widget.isSelected
                        ? Colors.transparent
                        : AppColors.glassBorder,
                width: _focused ? 2 : 1,
              ),
              boxShadow: _focused
                  ? const [
                      BoxShadow(color: Color(0x50FFFFFF), blurRadius: 12),
                      BoxShadow(color: AppColors.accentGlow, blurRadius: 16, spreadRadius: -4),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected ? Colors.white : AppColors.onSurface,
                fontSize: 15,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
