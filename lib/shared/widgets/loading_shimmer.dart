import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import 'poster_card.dart';

class LoadingShimmerRow extends StatelessWidget {
  final int count;
  const LoadingShimmerRow({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: const Color(0xFF3A3A46),
      child: Row(
        children: List.generate(count, (i) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Container(
            width: LandscapeCard.cardWidth,
            height: LandscapeCard.cardHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        )),
      ),
    );
  }
}

class LoadingShimmerGrid extends StatelessWidget {
  final int rows;
  final int cols;
  const LoadingShimmerGrid({super.key, this.rows = 3, this.cols = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: const Color(0xFF3A3A46),
      child: Column(
        children: List.generate(rows, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: List.generate(cols, (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  height: PosterCard.cardHeight,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )),
          ),
        )),
      ),
    );
  }
}
