import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/collections_carousel.dart';
import 'widgets/content_carousel.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/hero_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: SingleChildScrollView(
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
    );
  }
}
