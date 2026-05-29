import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/startup_model.dart';
import 'user_provider.dart';

final startupStreamProvider = StreamProvider<StartupModel?>((ref) {
  final user = ref.watch(userStreamProvider).value;
  
  if (user == null || user.startupId == null || user.startupId!.isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('startups')
      .doc(user.startupId)
      .snapshots()
      .map((doc) {
    if (doc.exists && doc.data() != null) {
      return StartupModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  });
});
