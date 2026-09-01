import '../models/app_entitlement.dart';
import '../models/app_user.dart';
import 'app_capabilities.dart';

class CapabilityResolver {
  const CapabilityResolver._();

  static AppCapabilities resolve({
    required AppUser? user,
    required AppEntitlement entitlement,
    DateTime? now,
  }) {
    if (user == null || !entitlement.isPremiumAt(now ?? DateTime.now())) {
      return AppCapabilities.anonymousFree;
    }
    return AppCapabilities.premiumLaunch;
  }
}
