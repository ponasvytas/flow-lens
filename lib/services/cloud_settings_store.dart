import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';

abstract interface class CloudSettingsStore {
  Future<AppSettings?> loadForUser(String userId);

  Future<void> saveForUser(String userId, AppSettings settings);
}

class FirestoreCloudSettingsStore implements CloudSettingsStore {
  FirestoreCloudSettingsStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<AppSettings?> loadForUser(String userId) async {
    final snapshot = await _firestore
        .doc('users/$userId/preferences/default')
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return AppSettings.fromMap(data);
  }

  @override
  Future<void> saveForUser(String userId, AppSettings settings) => _firestore
      .doc('users/$userId/preferences/default')
      .set({...settings.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
}
