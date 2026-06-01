import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/hdrezka_search.dart';
import 'session_provider.dart';

final fastSearchProvider = FutureProvider.family<List<FastSearchResult>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return [];
    final session = ref.watch(sessionProvider);
    return session.search(query);
  },
  name: 'fastSearchProvider',
);
