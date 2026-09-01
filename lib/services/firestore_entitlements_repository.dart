import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_entitlement.dart';
import 'entitlements_repository.dart';

class FirestoreEntitlementsRepository implements EntitlementsRepository {
  FirestoreEntitlementsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<AppEntitlement> watchForUser(String userId) => _firestore
      .doc('users/$userId/entitlements/current')
      .snapshots()
      .map(_fromSnapshot);

  AppEntitlement _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return AppEntitlement.free;

    final tier = switch (data['tier']) {
      'premium' => AccountTier.premium,
      'premiumPlus' || 'premium_plus' => AccountTier.premiumPlus,
      _ => AccountTier.free,
    };
    final status = data['status'] == 'active' || data['active'] == true
        ? EntitlementStatus.active
        : EntitlementStatus.inactive;
    final expiresAtValue = data['expiresAt'];
    final expiresAt = switch (expiresAtValue) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };

    return AppEntitlement(tier: tier, status: status, expiresAt: expiresAt);
  }
}
