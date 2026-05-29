import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listing_model.dart';
import '../utils/match_utils.dart';
import 'user_provider.dart';

// Stream of all listings with 'open' status
final rawOpenListingsProvider = StreamProvider<List<ListingModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('listings')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((snapshot) {
    final listings = snapshot.docs.map((doc) => ListingModel.fromMap(doc.data(), doc.id)).toList();
    listings.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort client-side to bypass index requirements
    return listings;
  });
});

// A structure to hold listing data alongside its computed match score details
class MatchedListing {
  final ListingModel listing;
  final double score;
  final List<String> matchedSkills;
  final List<String> missingSkills;

  MatchedListing({
    required this.listing,
    required this.score,
    required this.matchedSkills,
    required this.missingSkills,
  });
}

// Provider that matches and sorts open listings for the logged-in student
final studentMatchedListingsProvider = Provider<AsyncValue<List<MatchedListing>>>((ref) {
  final listingsAsync = ref.watch(rawOpenListingsProvider);
  final userAsync = ref.watch(userStreamProvider);

  // If listings or user is loading/error, propagate that state
  if (listingsAsync.isLoading || userAsync.isLoading) {
    return const AsyncLoading();
  }
  if (listingsAsync.hasError) {
    return AsyncError(listingsAsync.error!, listingsAsync.stackTrace!);
  }
  if (userAsync.hasError) {
    return AsyncError(userAsync.error!, userAsync.stackTrace!);
  }

  final listings = listingsAsync.value ?? [];
  final user = userAsync.value;
  final studentSkills = user?.skills ?? [];

  // Match and map listings
  final matchedListings = listings.map((listing) {
    final match = computeMatch(studentSkills, listing.requiredSkills);
    return MatchedListing(
      listing: listing,
      score: match['score'] as double,
      matchedSkills: List<String>.from(match['matchedSkills']),
      missingSkills: List<String>.from(match['missingSkills']),
    );
  }).toList();

  // Sort by match score descending
  matchedListings.sort((a, b) => b.score.compareTo(a.score));

  return AsyncValue.data(matchedListings);
});

class DiscoverFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';
  
  void update(String val) {
    state = val;
  }
}

final discoverFilterProvider = NotifierProvider<DiscoverFilterNotifier, String>(() {
  return DiscoverFilterNotifier();
});

// Provider to return filtered matched listings based on horizontal filters
final filteredDiscoverListingsProvider = Provider<AsyncValue<List<MatchedListing>>>((ref) {
  final matchedListingsAsync = ref.watch(studentMatchedListingsProvider);
  final activeFilter = ref.watch(discoverFilterProvider);

  return matchedListingsAsync.whenData((listings) {
    if (activeFilter == 'All') return listings;
    
    final lowerFilter = activeFilter.toLowerCase();
    
    return listings.where((m) {
      final listing = m.listing;
      
      // Match by Listing Type Badge
      if (lowerFilter == 'jobs' && listing.type == 'job') return true;
      if (lowerFilter == 'internships' && listing.type == 'internship') return true;
      if (lowerFilter == 'co-founder' && listing.type == 'cofounding') return true;
      if (lowerFilter == 'partnerships' && listing.type == 'partnership') return true;
      
      // Match by Location type
      if (lowerFilter == 'remote' && listing.locationType == 'remote') return true;
      if (lowerFilter == 'on-site' && listing.locationType == 'on-site') return true;
      if (lowerFilter == 'hybrid' && listing.locationType == 'hybrid') return true;
      
      return false;
    }).toList();
  });
});
