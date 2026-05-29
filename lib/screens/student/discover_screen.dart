import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/listings_provider.dart';
import '../../theme/app_colors.dart';
import 'listing_detail_screen.dart';
import 'search_screen.dart';
import '../../components/student/listing_card.dart';
import '../../services/ai_service.dart';
import '../../providers/user_provider.dart';

class StudentDiscoverScreen extends ConsumerStatefulWidget {
  const StudentDiscoverScreen({super.key});

  @override
  ConsumerState<StudentDiscoverScreen> createState() => _StudentDiscoverScreenState();
}

class _StudentDiscoverScreenState extends ConsumerState<StudentDiscoverScreen> {
  final _aiSearchController = TextEditingController();
  bool _isSearchingAI = false;
  List<Map<String, dynamic>>? _aiMatchedResults;

  Future<void> _performAISearch() async {
    final query = _aiSearchController.text.trim();
    if (query.isEmpty) return;

    ref.read(discoverFilterProvider.notifier).update('All');

    setState(() {
      _isSearchingAI = true;
    });

    try {
      final user = ref.read(userStreamProvider).value;
      final studentSkills = user?.skills ?? [];
      final listingsAsync = ref.read(rawOpenListingsProvider);
      final listings = listingsAsync.value ?? [];
      print('DEBUG: _performAISearch query: "$query", listing count: ${listings.length}');

      final results = await AIService.findMatchingListings(
        userQuery: query,
        studentSkills: studentSkills,
        listings: listings.map((l) => l.toMap()..['listingId'] = l.listingId).toList(),
      );

      if (mounted) {
        if (results == null || results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No matching listings found.'),
              backgroundColor: Colors.amber,
            ),
          );
          setState(() {
            _aiMatchedResults = null;
          });
        } else {
          setState(() {
            _aiMatchedResults = results;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI search failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingAI = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _aiSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredListingsAsync = ref.watch(filteredDiscoverListingsProvider);
    final activeFilter = ref.watch(discoverFilterProvider);

    final filters = [
      'All', 'Jobs', 'Internships', 'Co-founder', 'Partnerships', 'Remote', 'On-site'
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Roles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Conversational Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _aiSearchController,
              decoration: InputDecoration(
                hintText: "Ask AI: 'Looking for Flutter roles with Rs 15k stipend'",
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMutedLight),
                prefixIcon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                suffixIcon: _isSearchingAI
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : _aiMatchedResults != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.errorRed),
                            onPressed: () {
                              _aiSearchController.clear();
                              setState(() {
                                _aiMatchedResults = null;
                              });
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: _performAISearch,
                          ),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.dividerDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.dividerDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => _performAISearch(),
            ),
          ),

          // Filter horizontal list
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      filter.startsWith('#') ? filter : '#$filter',
                      style: TextStyle(
                        color: isSelected ? AppColors.textDark : AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.cardDark,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(discoverFilterProvider.notifier).update(filter);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(rawOpenListingsProvider);
              },
              child: filteredListingsAsync.when(
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (_, __) => const _ShimmerListingCard(),
                ),
                error: (err, _) => Center(
                  child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed)),
                ),
                data: (matchedListings) {
                  print('DEBUG UI: matchedListings count: ${matchedListings.length}');
                  print('DEBUG UI: matchedListings IDs: ${matchedListings.map((m) => m.listing.listingId).toList()}');
                  print('DEBUG UI: _aiMatchedResults: $_aiMatchedResults');
                  final displayList = _aiMatchedResults != null
                      ? matchedListings.where((m) {
                          return _aiMatchedResults!.any((res) {
                            final matchedId = res['listingId'] ?? res['id'];
                            return matchedId?.toString().toLowerCase().trim() == m.listing.listingId.toLowerCase().trim();
                          });
                        }).toList()
                      : matchedListings;

                  if (displayList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_outlined, size: 64, color: AppColors.textMutedLight),
                          const SizedBox(height: 16),
                          Text('No matches found', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(_aiMatchedResults != null ? 'Try a different AI search query.' : 'Try modifying your search filter.', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    );
                  }

                  // Rendered Cream Containers
                  return Theme(
                    data: Theme.of(context).copyWith(
                      cardTheme: Theme.of(context).cardTheme.copyWith(color: AppColors.cardLight),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final matched = displayList[index];
                        final listing = matched.listing;
                        final aiResult = _aiMatchedResults?.firstWhere(
                          (res) => (res['listingId'] ?? res['id'])?.toString().toLowerCase().trim() == listing.listingId.toLowerCase().trim(),
                          orElse: () => <String, dynamic>{},
                        );
                        final fitReason = (aiResult?['reason'] ?? aiResult?['fitReason']) as String?;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentListingDetailScreen(matchedListing: matched),
                                    ),
                                  );
                                },
                                child: ListingCard(
                                  listing: listing,
                                  matchScore: matched.score,
                                  matchedSkills: matched.matchedSkills,
                                ),
                              ),
                              if (fitReason != null && fitReason.isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(left: 4, right: 4, top: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          fitReason,
                                          style: const TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerListingCard extends StatelessWidget {
  const _ShimmerListingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: AppColors.dividerDark, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 10, color: AppColors.dividerDark),
                      const SizedBox(height: 8),
                      Container(width: 180, height: 16, color: AppColors.dividerDark),
                    ],
                  ),
                ),
                Container(width: 48, height: 36, color: AppColors.dividerDark),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(width: 64, height: 24, decoration: BoxDecoration(color: AppColors.dividerDark, borderRadius: BorderRadius.circular(12))),
                const SizedBox(width: 8),
                Container(width: 64, height: 24, decoration: BoxDecoration(color: AppColors.dividerDark, borderRadius: BorderRadius.circular(12))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
