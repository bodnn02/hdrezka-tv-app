import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/category/category_screen.dart';
import 'features/details/details_screen.dart';
import 'features/home/home_screen.dart';
import 'features/player/player_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/splash/splash_screen.dart';
import 'shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (_, _) => const SearchScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/films',
            builder: (_, _) => const CategoryScreen(title: 'Фильмы', category: 'films'),
          ),
          GoRoute(
            path: '/series',
            builder: (_, _) => const CategoryScreen(title: 'Сериалы', category: 'series'),
          ),
          GoRoute(
            path: '/cartoons',
            builder: (_, _) => const CategoryScreen(title: 'Мультфильмы', category: 'cartoons'),
          ),
          GoRoute(
            path: '/anime',
            builder: (_, _) => const CategoryScreen(title: 'Аниме', category: 'animation'),
          ),
        ],
      ),
      GoRoute(
        path: '/details/:url',
        builder: (context, state) {
          final url = Uri.decodeComponent(state.pathParameters['url']!);
          return DetailsScreen(contentUrl: url);
        },
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final rawUrl = q['url'] ?? '';
          final url = rawUrl.contains('%') ? Uri.decodeComponent(rawUrl) : rawUrl;
          return PlayerScreen(
            contentUrl:   url,
            season:       int.tryParse(q['season']  ?? ''),
            episode:      int.tryParse(q['episode'] ?? ''),
            translatorId: int.tryParse(q['tr']      ?? ''),
          );
        },
      ),
    ],
  );
}, name: 'appRouterProvider');
