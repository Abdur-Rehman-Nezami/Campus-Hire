import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listing_model.dart';
import '../models/application_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'startup_provider.dart';

// Stream of all listings created by the logged-in founder
final founderListingsProvider = StreamProvider<List<ListingModel>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  
  if (authUser == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('listings')
      .where('founderId', isEqualTo: authUser.uid)
      .snapshots()
      .map((snapshot) {
    final listings = snapshot.docs.map((doc) => ListingModel.fromMap(doc.data(), doc.id)).toList();
    listings.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Client-side sort to avoid index setup
    return listings;
  });
});

// Applicant details wrapped with their user profile data
class HydratedApplicant {
  final ApplicationModel application;
  final UserModel student;
  final ListingModel listing;

  HydratedApplicant({
    required this.application,
    required this.student,
    required this.listing,
  });
}

// Stream of all applications submitted to the founder's startup roles
final founderApplicantsProvider = StreamProvider<List<HydratedApplicant>>((ref) {
  final startup = ref.watch(startupStreamProvider).value;
  
  if (startup == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('applications')
      .where('startupId', isEqualTo: startup.startupId)
      .snapshots()
      .asyncMap((snapshot) async {
        final hydratedApplicants = <HydratedApplicant>[];
        
        for (var doc in snapshot.docs) {
          final app = ApplicationModel.fromMap(doc.data(), doc.id);
          
          try {
            // Fetch student's profile
            final studentDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(app.studentId)
                .get();
                
            // Fetch associated listing details
            final listingDoc = await FirebaseFirestore.instance
                .collection('listings')
                .doc(app.listingId)
                .get();
                
            if (studentDoc.exists && studentDoc.data() != null && listingDoc.exists && listingDoc.data() != null) {
              final student = UserModel.fromMap(studentDoc.data()!, studentDoc.id);
              final listing = ListingModel.fromMap(listingDoc.data()!, listingDoc.id);
              
              hydratedApplicants.add(HydratedApplicant(
                application: app,
                student: student,
                listing: listing,
              ));
            }
          } catch (_) {
            // Skip hydration failures quietly
          }
        }
        
        // Sort by application date descending
        hydratedApplicants.sort((a, b) => b.application.createdAt.compareTo(a.application.createdAt));
        return hydratedApplicants;
      });
});
