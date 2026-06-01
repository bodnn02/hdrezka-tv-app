import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/hdrezka_browse.dart';
import '../core/api/hdrezka_search.dart';
import 'session_provider.dart';

final categoryContentProvider = FutureProvider.family<List<AdvancedSearchResult>, ({String category, int page, String filter})>(
  (ref, params) async {
    final session = ref.watch(sessionProvider);
    return HdRezkaBrowse.getCategory(
      session,
      params.category,
      page: params.page,
      filter: params.filter,
    );
  },
  name: 'categoryContentProvider',
);

// Home section providers — each fetches first page with a specific filter
// Uses 'films' as the broadest mixed category on HDRezka

final newReleasesProvider = FutureProvider<List<AdvancedSearchResult>>(
  (ref) async {
    final session = ref.watch(sessionProvider);
    return HdRezkaBrowse.getCategory(session, 'films', filter: 'last');
  },
  name: 'newReleasesProvider',
);

final popularNowProvider = FutureProvider<List<AdvancedSearchResult>>(
  (ref) async {
    final session = ref.watch(sessionProvider);
    return HdRezkaBrowse.getCategory(session, 'films', filter: 'popular');
  },
  name: 'popularNowProvider',
);

final watchingNowProvider = FutureProvider<List<AdvancedSearchResult>>(
  (ref) async {
    final session = ref.watch(sessionProvider);
    return HdRezkaBrowse.getCategory(session, 'films', filter: 'watching');
  },
  name: 'watchingNowProvider',
);

final comingSoonProvider = FutureProvider<List<AdvancedSearchResult>>(
  (ref) async {
    final session = ref.watch(sessionProvider);
    return HdRezkaBrowse.getCategory(session, 'films', filter: 'soon');
  },
  name: 'comingSoonProvider',
);

final collectionsProvider = FutureProvider<List<CollectionResult>>(
  (ref) async {
    final session = ref.watch(sessionProvider);
    return HdRezkaBrowse.getCollections(session);
  },
  name: 'collectionsProvider',
);
