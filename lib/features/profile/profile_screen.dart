import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/app_shell.dart';
import '../../core/services/bookmarks_service.dart';
import '../../core/services/watch_history_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_state.dart';
import '../../providers/tmdb_provider.dart';
import '../../providers/update_provider.dart';
import '../../shared/widgets/focusable_card.dart';
import '../../shared/widgets/update_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 0; // 0=history 1=bookmarks 2=settings

  @override
  Widget build(BuildContext context) {
    final isAuthed  = ref.watch(authProvider) is AuthAuthenticated;
    final history   = ref.watch(watchHistoryProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            AppShell.focusTopBar(context);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Glass sidebar ──────────────────────────────────────────
            SizedBox(
              width: 280,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x30FFFFFF), Color(0x0CFFFFFF)],
                      ),
                      border: Border(
                        right: BorderSide(color: AppColors.glassBorder, width: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AccountCard(isAuthed: isAuthed),
                        const SizedBox(height: 28),
                        Container(height: 0.5, color: AppColors.glassBorder),
                        const SizedBox(height: 20),

                        _GlassTab(
                          icon: Icons.history_rounded,
                          label: 'История',
                          count: history.length,
                          selected: _tab == 0,
                          onSelect: () => setState(() => _tab = 0),
                        ),
                        const SizedBox(height: 8),
                        _GlassTab(
                          icon: Icons.bookmark_rounded,
                          label: 'Закладки',
                          count: bookmarks.length,
                          selected: _tab == 1,
                          onSelect: () => setState(() => _tab = 1),
                        ),
                        const SizedBox(height: 8),
                        _GlassTab(
                          icon: Icons.settings_rounded,
                          label: 'Настройки',
                          count: 0,
                          selected: _tab == 2,
                          onSelect: () => setState(() => _tab = 2),
                        ),

                        const Spacer(),

                        _UpdateButton(),
                        const SizedBox(height: 8),

                        if (isAuthed)
                          _GlassActionButton(
                            icon: Icons.logout_rounded,
                            label: 'Выйти',
                            danger: true,
                            onSelect: () => ref.read(authProvider.notifier).logout(),
                          )
                        else
                          _GlassActionButton(
                            icon: Icons.login_rounded,
                            label: 'Войти',
                            onSelect: () => context.push('/login'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Content pane ───────────────────────────────────────────
            Expanded(
              child: switch (_tab) {
                0 => _HistoryTab(history: history),
                1 => _BookmarksTab(bookmarks: bookmarks),
                _ => const _SettingsTab(),
              },
            ),
          ],
        ),
        ),   // Padding
      ),     // Focus
    );
  }
}

// ── Account card ───────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final bool isAuthed;
  const _AccountCard({required this.isAuthed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isAuthed
                ? const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isAuthed ? null : AppColors.glassFillStrong,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(
            isAuthed ? Icons.person_rounded : Icons.person_outline_rounded,
            color: Colors.white, size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAuthed ? 'Мой аккаунт' : 'Гость',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                isAuthed ? 'HDRezka' : 'Войдите для доступа',
                style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Glass tab ──────────────────────────────────────────────────────────────────

class _GlassTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelect;

  const _GlassTab({
    required this.icon, required this.label, required this.count,
    required this.selected, required this.onSelect,
  });

  @override
  State<_GlassTab> createState() => _GlassTabState();
}

class _GlassTabState extends State<_GlassTab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused;

    return Focus(
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(widget.selected ? 45 : 25),
                      Colors.white.withAlpha(widget.selected ? 18 : 10),
                    ],
                  )
                : null,
            border: Border.all(
              color: _focused
                  ? AppColors.glassBorderFocus
                  : widget.selected
                      ? AppColors.glassBorder
                      : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? const [BoxShadow(color: Color(0x40FFFFFF), blurRadius: 14)]
                : null,
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  color: active ? AppColors.accent : AppColors.onSurfaceMuted,
                  size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.onSurfaceMuted,
                    fontSize: 15,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.selected ? AppColors.accent : AppColors.glassFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────────

class _GlassActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onSelect;
  final bool danger;

  const _GlassActionButton({
    required this.icon, required this.label, required this.onSelect, this.danger = false,
  });

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? Colors.redAccent : AppColors.accent;

    return Focus(
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _focused ? color.withAlpha(35) : Colors.transparent,
            border: Border.all(
              color: _focused ? AppColors.glassBorderFocus : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 19),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History tab ────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  final List<WatchHistoryEntry> history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        message: 'История пуста',
        subtitle: 'Начните смотреть — здесь появятся ваши просмотры',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 4),
          child: Row(
            children: [
              Text('История просмотра', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FocusableCard(
                borderRadius: BorderRadius.circular(50),
                onSelect: () => ref.read(watchHistoryProvider.notifier).clear(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Text(
                    'Очистить всё',
                    style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            itemCount: history.length,
            itemBuilder: (ctx, i) => _HistoryItem(entry: history[i]),
          ),
        ),
      ],
    );
  }
}

class _HistoryItem extends ConsumerWidget {
  final WatchHistoryEntry entry;
  const _HistoryItem({required this.entry});

  void _open(BuildContext context) {
    final params = <String, String>{'url': Uri.encodeComponent(entry.url)};
    if (entry.season != null)       params['season']  = '${entry.season}';
    if (entry.episode != null)      params['episode'] = '${entry.episode}';
    if (entry.translatorId != null) params['tr']      = '${entry.translatorId}';
    context.push(Uri(path: '/player', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusableCard(
        borderRadius: BorderRadius.circular(14),
        onSelect: () => _open(context),
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x20FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 107, height: 60,
                  child: entry.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: entry.thumbnail,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
                        )
                      : Container(color: AppColors.surfaceVariant),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(),
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(height: 3, color: Colors.white.withAlpha(25)),
                          FractionallySizedBox(
                            widthFactor: entry.progress,
                            child: Container(
                              height: 3,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.accent, AppColors.accentSecondary],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FocusableCard(
                borderRadius: BorderRadius.circular(50),
                onSelect: () => ref.read(watchHistoryProvider.notifier)
                    .remove(entry.url, season: entry.season, episode: entry.episode),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close_rounded, color: AppColors.onSurfaceMuted, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (entry.season != null && entry.episode != null) {
      parts.add('С${entry.season} · Е${entry.episode}');
    }
    final t = entry.total;
    if (t != null && t.inSeconds > 0) {
      parts.add('${(entry.progress * 100).round()}%');
    }
    return parts.join('  ');
  }
}

// ── Bookmarks tab ──────────────────────────────────────────────────────────────

class _BookmarksTab extends ConsumerWidget {
  final List<BookmarkEntry> bookmarks;
  const _BookmarksTab({required this.bookmarks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookmarks.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_border_rounded,
        message: 'Закладок нет',
        subtitle: 'Добавляйте фильмы через кнопку на странице контента',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 4),
          child: Row(
            children: [
              Text('Закладки', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FocusableCard(
                borderRadius: BorderRadius.circular(50),
                onSelect: () => ref.read(bookmarksProvider.notifier).clear(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Text(
                    'Очистить всё',
                    style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 160 / 240,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: bookmarks.length,
            itemBuilder: (ctx, i) => _BookmarkCard(entry: bookmarks[i]),
          ),
        ),
      ],
    );
  }
}

class _BookmarkCard extends ConsumerWidget {
  final BookmarkEntry entry;
  const _BookmarkCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusableCard(
      borderRadius: BorderRadius.circular(14),
      onSelect: () => context.push('/details/${Uri.encodeComponent(entry.url)}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            entry.thumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: entry.thumbnail,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
                  )
                : Container(color: AppColors.surfaceVariant),
            // Gradient label
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 22, 9, 10),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
                child: Text(
                  entry.title,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Remove button
            Positioned(
              top: 6, right: 6,
              child: FocusableCard(
                borderRadius: BorderRadius.circular(50),
                onSelect: () => ref.read(bookmarksProvider.notifier).remove(entry.url),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.glassFillStrong,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Update button ──────────────────────────────────────────────────────────────

class _UpdateButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends ConsumerState<_UpdateButton> {
  bool _focused = false;

  Future<void> _checkAndShow() async {
    final notifier = ref.read(updateCheckProvider.notifier);
    await notifier.check();
    if (!mounted) return;
    final state = ref.read(updateCheckProvider);
    if (state is UpdateCheckAvailable) {
      UpdateDialog.show(context, state.release);
    } else if (state is UpdateCheckUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У вас уже установлена последняя версия.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else if (state is UpdateCheckError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка проверки обновлений: ${state.message}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkState = ref.watch(updateCheckProvider);
    final isLoading = checkState is UpdateCheckLoading;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (!isLoading &&
            event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          _checkAndShow();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: isLoading ? null : _checkAndShow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _focused ? AppColors.accent.withAlpha(35) : Colors.transparent,
            border: Border.all(
              color: _focused ? AppColors.glassBorderFocus : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 19, height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                const Icon(Icons.system_update_rounded, color: AppColors.accent, size: 19),
              const SizedBox(width: 10),
              Text(
                isLoading ? 'Проверка…' : 'Обновления',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings tab ──────────────────────────────────────────────────────────────

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late final TextEditingController _tmdbController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _tmdbController = TextEditingController(
      text: ref.read(tmdbApiKeyProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _tmdbController.dispose();
    super.dispose();
  }

  Future<void> _saveTmdbKey() async {
    final key = _tmdbController.text.trim();
    if (key.isEmpty) {
      await ref.read(tmdbApiKeyProvider.notifier).clear();
    } else {
      await ref.read(tmdbApiKeyProvider.notifier).save(key);
    }
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Настройки', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 28),

          // ── TMDB section ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.glassFill,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D253F), Color(0xFF01B4E4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.movie_filter_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TMDB API',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text('Кадры из фильма (fallback)',
                            style: TextStyle(
                                color: AppColors.onSurfaceMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Если HDRezka не предоставляет кадры для фильма, '
                  'приложение загрузит их с The Movie Database. '
                  'Получите бесплатный ключ на themoviedb.org → Settings → API.',
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 16),
                // Key input field
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.surfaceVariant,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: TextField(
                    controller: _tmdbController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Bearer токен (начинается с eyJ…)',
                      hintStyle: TextStyle(
                          color: AppColors.onSurfaceSubtle, fontSize: 13),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: InputBorder.none,
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _saveTmdbKey(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FocusableCard(
                      borderRadius: BorderRadius.circular(50),
                      onSelect: _saveTmdbKey,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: _saved
                              ? const LinearGradient(
                                  colors: [Color(0xFF34C759), Color(0xFF30D158)],
                                )
                              : const LinearGradient(
                                  colors: [
                                    AppColors.accent,
                                    AppColors.accentSecondary
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _saved
                                  ? Icons.check_rounded
                                  : Icons.save_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _saved ? 'Сохранено' : 'Сохранить',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Clear button — show only if key is set
                    if ((ref.watch(tmdbApiKeyProvider) ?? '').isNotEmpty)
                      FocusableCard(
                        borderRadius: BorderRadius.circular(50),
                        onSelect: () async {
                          _tmdbController.clear();
                          await ref.read(tmdbApiKeyProvider.notifier).clear();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: AppColors.glassFill,
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: const Text('Удалить ключ',
                              style: TextStyle(
                                  color: AppColors.onSurfaceMuted,
                                  fontSize: 14)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  const _EmptyState({required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onSurfaceSubtle, size: 64),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
