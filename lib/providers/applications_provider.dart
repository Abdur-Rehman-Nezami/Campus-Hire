import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/application_model.dart';
import 'auth_provider.dart';

// Stream of all applications submitted by the logged-in student
final studentApplicationsProvider = StreamProvider<List<ApplicationModel>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  
  if (authUser == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('applications')
      .where('studentId', isEqualTo: authUser.uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final applications = <ApplicationModel>[];
        
        for (var doc in snapshot.docs) {
          final app = ApplicationModel.fromMap(doc.data(), doc.id);
          
          // Hydrate listing details if not stored natively (to support rich cards)
          try {
            final listingDoc = await FirebaseFirestore.instance
                .collection('listings')
                .doc(app.listingId)
                .get();
                
            if (listingDoc.exists && listingDoc.data() != null) {
              final listingData = listingDoc.data()!;
              app.listingTitle = listingData['title'];
              app.startupName = listingData['startupName'];
              app.startupSector = listingData['startupSector'];
              app.compensationDetails = listingData['compensationDetails'] ?? listingData['compensationType'];
            }
          } catch (_) {
            // Fallback quietly if fetching fails
          }
          
          applications.add(app);
        }
        
        applications.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort client-side to bypass index requirements
        return applications;
      });
});

// A provider to check if the student has already applied to a specific listing
final hasAppliedToListingProvider = Provider.family<bool, String>((ref, listingId) {
  final appsAsync = ref.watch(studentApplicationsProvider);
  return appsAsync.maybeWhen(
    data: (apps) => apps.any((app) => app.listingId == listingId),
    orElse: () => false,
  );
});

// A provider to get the student's application for a specific listing
final studentApplicationForListingProvider = Provider.family<ApplicationModel?, String>((ref, listingId) {
  final appsAsync = ref.watch(studentApplicationsProvider);
  return appsAsync.maybeWhen(
    data: (apps) {
      final index = apps.indexWhere((app) => app.listingId == listingId);
      return index != -1 ? apps[index] : null;
    },
    orElse: () => null,
  );
});

