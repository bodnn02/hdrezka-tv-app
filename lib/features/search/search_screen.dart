import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/hdrezka_search.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/search_provider.dart';
import 'widgets/search_result_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller  = TextEditingController();
  final _fieldFocus  = FocusNode();
  Timer? _debounce;
  String _query = '';
  int _selectedIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() { _query = value; _selectedIndex = 0; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(fastSearchProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Soft radial glow in background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.4),
                  radius: 1.2,
                  colors: [Color(0x1A2C7DFF), Colors.transparent],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(TvSafe.h, 8, TvSafe.h, TvSafe.v),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left panel: glass card ────────────────────────────
                SizedBox(
                  width: 420,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0x30FFFFFF), Color(0x0CFFFFFF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Glass search field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _GlassSearchField(
                                controller: _controller,
                                focusNode: _fieldFocus,
                                onChanged: _onChanged,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Results list
                            Expanded(
                              child: resultsAsync.when(
                                loading: () => const Center(
                                  child: SizedBox(
                                    width: 26, height: 26,
                                    child: CircularProgressIndicator(
                                      color: AppColors.accent, strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                error: (e, _) => Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text('Ошибка: $e',
                                      style: const TextStyle(color: Colors.red, fontSize: 14)),
                                ),
                                data: (items) {
                                  if (items.isEmpty && _query.isNotEmpty) {
                                    return const Center(
                                      child: Text(
                                        'Ничего не найдено',
                                        style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 16),
                                      ),
                                    );
                                  }
                                  if (items.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'Начните вводить запрос',
                                        style: TextStyle(color: AppColors.onSurfaceSubtle, fontSize: 15),
                                      ),
                                    );
                                  }
                                  return FocusTraversalGroup(
                                    policy: ReadingOrderTraversalPolicy(),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                      itemCount: items.length,
                                      itemBuilder: (context, i) => SearchResultCard(
                                        item: items[i],
                                        isSelected: _selectedIndex == i,
                                        onFocused: (f) {
                                          if (f) setState(() => _selectedIndex = i);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),

                // ── Right panel: preview ──────────────────────────────
                Expanded(
                  child: resultsAsync.maybeWhen(
                    data: (items) => items.isNotEmpty
                        ? _SearchPreview(
                            item: items[_selectedIndex.clamp(0, items.length - 1)],
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),    // Stack
    );
  }
}

// ── Glass search field ─────────────────────────────────────────────────────────

class _GlassSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;

  const _GlassSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        hintText: 'Поиск фильмов и сериалов…',
        hintStyle: const TextStyle(color: AppColors.onSurfaceSubtle, fontSize: 16),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.onSurfaceMuted, size: 20),
        filled: true,
        fillColor: AppColors.glassFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorderFocus, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

// ── Right-side preview ─────────────────────────────────────────────────────────

class _SearchPreview extends StatelessWidget {
  final FastSearchResult item;
  const _SearchPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.rating != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFD60A), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    item.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFFFFD60A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            item.url,
            style: const TextStyle(color: AppColors.onSurfaceSubtle, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
