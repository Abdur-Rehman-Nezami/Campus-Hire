import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/listings_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/student/listing_card.dart';
import 'listing_detail_screen.dart';
import '../../utils/match_utils.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<String> _recentSearches = [];
  Timer? _debounceTimer;
  String _currentQuery = '';

  final List<String> _categories = [
    'Software', 'Design', 'Marketing', 'Product', 'Data', 'Finance'
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    
    if (_recentSearches.length > 5) {
      _recentSearches = _recentSearches.sublist(0, 5);
    }
    
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  void _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() => _currentQuery = query.toLowerCase().trim());
      if (_currentQuery.isNotEmpty) {
        _saveSearchQuery(_currentQuery);
      }
    });
  }

  void _executeSearch(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentProfile = ref.watch(userStreamProvider).value;
    final listingsAsync = ref.watch(rawOpenListingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search roles, skills, or startups...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.textMutedLight),
          ),
          style: const TextStyle(color: AppColors.textLight),
          onChanged: _onSearchChanged,
          onSubmitted: _saveSearchQuery,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _currentQuery.isEmpty
          ? _buildInitialState()
          : _buildSearchResults(listingsAsync, studentProfile?.skills ?? []),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browse Categories
          Text('Browse Categories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _categories.map((cat) => ActionChip(
              label: Text(cat, style: const TextStyle(color: AppColors.textLight)),
              backgroundColor: AppColors.cardDark,
              side: const BorderSide(color: AppColors.dividerDark),
              onPressed: () => _executeSearch(cat),
            )).toList(),
          ),
          const SizedBox(height: 48),

          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Text('Recent Searches', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ..._recentSearches.map((query) => Dismissible(
              key: Key(query),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _removeRecentSearch(query),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: AppColors.errorRed.withOpacity(0.2),
                child: const Icon(Icons.delete, color: AppColors.errorRed),
              ),
              child: ListTile(
                leading: const Icon(Icons.history, color: AppColors.textMutedLight),
                title: Text(query, style: const TextStyle(color: AppColors.textLight)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMutedLight),
                contentPadding: EdgeInsets.zero,
                onTap: () => _executeSearch(query),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue listingsAsync, List<String> studentSkills) {
    return listingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed))),
      data: (listings) {
        // Filter logic: match title, startupName, sector, or skills
        final results = listings.where((listing) {
          final textToSearch = '${listing.title} ${listing.startupName} ${listing.startupSector} ${listing.requiredSkills.join(" ")}'.toLowerCase();
          return textToSearch.contains(_currentQuery);
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('No matching roles found.'));
        }

        // Map to MatchedListing and sort by match score
        final matchedResults = results.map((listing) {
          final matchData = computeMatch(studentSkills, listing.requiredSkills);
          return MatchedListing(
            listing: listing,
            score: matchData['score'],
            matchedSkills: matchData['matchedSkills'],
            missingSkills: matchData['missingSkills'],
          );
        }).toList();

        matchedResults.sort((a, b) => b.score.compareTo(a.score));

        return ListView.separated(
          padding: const EdgeInsets.all(24.0),
          itemCount: matchedResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final match = matchedResults[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentListingDetailScreen(matchedListing: match)),
              ),
              child: ListingCard(
                listing: match.listing,
                matchScore: match.score,
                matchedSkills: match.matchedSkills,
              ),
            );
          },
        );
      },
    );
  }
}
