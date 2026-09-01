import '../models/app_entitlement.dart';

abstract interface class EntitlementsRepository {
  Stream<AppEntitlement> watchForUser(String userId);
}

class FreeEntitlementsRepository implements EntitlementsRepository {
  @override
  Stream<AppEntitlement> watchForUser(String userId) =>
      Stream.value(AppEntitlement.free);
}
