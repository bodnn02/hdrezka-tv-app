import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_shell.dart';
import 'widgets/collections_carousel.dart';
import 'widgets/content_carousel.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/hero_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      // Move focus to the top navigation bar when at the scroll top
      if (_scrollController.hasClients &&
          _scrollController.offset <= 0) {
        AppShell.focusTopBar(context);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        onKeyEvent: _handleKey,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: TvSafe.navBarHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeroBanner(),
                const ContinueWatchingRow(),
                const ContentCarousel(title: 'Новые релизы',    category: 'films',  filter: 'last'),
                const ContentCarousel(title: 'Популярное',      category: 'films',  filter: 'popular'),
                const ContentCarousel(title: 'Сейчас смотрят', category: 'films',  filter: 'watching'),
                const ContentCarousel(title: 'В ожидании',     category: 'films',  filter: 'soon'),
                const CollectionsCarousel(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
