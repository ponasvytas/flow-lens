enum AccountTier { free, premium, premiumPlus }

enum EntitlementStatus { unknown, inactive, active }

class AppEntitlement {
  const AppEntitlement({
    required this.tier,
    required this.status,
    this.expiresAt,
  });

  static const unknown = AppEntitlement(
    tier: AccountTier.free,
    status: EntitlementStatus.unknown,
  );

  static const free = AppEntitlement(
    tier: AccountTier.free,
    status: EntitlementStatus.inactive,
  );

  final AccountTier tier;
  final EntitlementStatus status;
  final DateTime? expiresAt;

  bool isPremiumAt(DateTime now) {
    if (status != EntitlementStatus.active || tier == AccountTier.free) {
      return false;
    }
    return expiresAt == null || expiresAt!.isAfter(now);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppEntitlement &&
          other.tier == tier &&
          other.status == status &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(tier, status, expiresAt);
}
