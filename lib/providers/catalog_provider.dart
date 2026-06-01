import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/hdrezka_browse.dart';
import '../core/api/hdrezka_search.dart' show AdvancedSearchResult;
import 'session_provider.dart';

class CatalogFilters {
  final String sortFilter; // watching | last | popular | soon
  final String? genre;
  final int? yearFrom;
  final int? yearTo;
  final String searchQuery;

  const CatalogFilters({
    this.sortFilter = 'watching',
    this.genre,
    this.yearFrom,
    this.yearTo,
    this.searchQuery = '',
  });

  bool get hasActiveFilters =>
      genre != null || yearFrom != null || yearTo != null || searchQuery.isNotEmpty;

  CatalogFilters copyWith({
    String? sortFilter,
    Object? genre = _sentinel,
    Object? yearFrom = _sentinel,
    Object? yearTo = _sentinel,
    String? searchQuery,
  }) {
    return CatalogFilters(
      sortFilter: sortFilter ?? this.sortFilter,
      genre: genre == _sentinel ? this.genre : genre as String?,
      yearFrom: yearFrom == _sentinel ? this.yearFrom : yearFrom as int?,
      yearTo: yearTo == _sentinel ? this.yearTo : yearTo as int?,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CatalogFilters &&
      sortFilter == other.sortFilter &&
      genre == other.genre &&
      yearFrom == other.yearFrom &&
      yearTo == other.yearTo &&
      searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(sortFilter, genre, yearFrom, yearTo, searchQuery);
}

// Sentinel for copyWith nullable fields
const _sentinel = Object();

class CatalogState {
  final List<AdvancedSearchResult> items;
  final CatalogFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const CatalogState({
    this.items = const [],
    this.filters = const CatalogFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  CatalogState copyWith({
    List<AdvancedSearchResult>? items,
    CatalogFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? error = _sentinel,
  }) {
    return CatalogState(
      items: items ?? this.items,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  final Ref _ref;
  final String _category;
  Timer? _searchDebounce;

  CatalogNotifier(this._ref, this._category) : super(const CatalogState()) {
    _fetchPage(1, reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPage(int page, {bool reset = false}) async {
    if (!mounted) return;
    if (reset) {
      state = state.copyWith(
        isLoading: true,
        error: null,
        items: const [],
        currentPage: 0,
        hasMore: true,
      );
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final session = _ref.read(sessionProvider);
      final filters = state.filters;
      List<AdvancedSearchResult> newItems;

      if (filters.searchQuery.isNotEmpty) {
        final result = await session.searchEngine.advancedSearch(filters.searchQuery, page: page);
        // Filter results to this category
        newItems = result.items.where((item) {
          if (_category == 'animation') return item.url.contains('/animation/');
          return item.url.contains('/$_category/');
        }).toList();
      } else {
        // Paginate by year range: if yearFrom == yearTo, fetch that year directly.
        // If a range is selected we fetch each year page sequentially (only for first load).
        // For simplicity: use yearFrom as the primary year filter; yearTo is a client-side clamp.
        newItems = await HdRezkaBrowse.getCategory(
          session,
          _category,
          page: page,
          filter: filters.sortFilter,
          genre: filters.genre,
          year: filters.yearFrom,
        );
      }

      if (!mounted) return;

      final allItems = reset ? newItems : [...state.items, ...newItems];
      state = state.copyWith(
        items: allItems,
        isLoading: false,
        isLoadingMore: false,
        currentPage: page,
        hasMore: newItems.isNotEmpty,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await _fetchPage(state.currentPage + 1);
  }

  void setSortFilter(String filter) {
    if (state.filters.sortFilter == filter) return;
    state = state.copyWith(filters: state.filters.copyWith(sortFilter: filter));
    _fetchPage(1, reset: true);
  }

  void setGenre(String? genre) {
    if (state.filters.genre == genre) return;
    state = state.copyWith(filters: state.filters.copyWith(genre: genre));
    _fetchPage(1, reset: true);
  }

  void setYearFrom(int? year) {
    if (state.filters.yearFrom == year) return;
    state = state.copyWith(filters: state.filters.copyWith(yearFrom: year));
    _fetchPage(1, reset: true);
  }

  void setYearTo(int? year) {
    // yearTo is only used for client-side display; HDrezka doesn't support range natively
    state = state.copyWith(filters: state.filters.copyWith(yearTo: year));
  }

  void setSearchQuery(String query) {
    _searchDebounce?.cancel();
    if (state.filters.searchQuery == query) return;
    state = state.copyWith(filters: state.filters.copyWith(searchQuery: query));
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchPage(1, reset: true);
    });
  }

  void clearFilters() {
    state = state.copyWith(filters: const CatalogFilters());
    _fetchPage(1, reset: true);
  }

  Future<void> refresh() => _fetchPage(1, reset: true);
}

// Family provider — one notifier per category string
final catalogProvider = StateNotifierProvider.family<CatalogNotifier, CatalogState, String>(
  (ref, category) => CatalogNotifier(ref, category),
  name: 'catalogProvider',
);
