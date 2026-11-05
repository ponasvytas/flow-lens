import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_options.dart';
import '../utils/app_log.dart';
import 'app_composition.dart';
import 'backend_environment.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppComposition> create() async {
    try {
      if (BackendEnvironment.current.useEmulators) {
        return await _createEmulated();
      }
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return AppComposition.firebase();
    } catch (error) {
      AppLog.debug(
        'Firebase initialization unavailable; starting local mode: $error',
      );
      return AppComposition.local();
    }
  }

  static Future<AppComposition> _createEmulated() async {
    const environment = BackendEnvironment.current;
    final existing = Firebase.apps
        .where((app) => app.name == BackendEnvironment.demoAppName)
        .firstOrNull;
    final app =
        existing ??
        await Firebase.initializeApp(
          name: BackendEnvironment.demoAppName,
          options: BackendEnvironment.demoOptions,
        );
    final auth = FirebaseAuth.instanceFor(app: app);
    final database = FirebaseFirestore.instanceFor(app: app);
    if (existing == null) {
      try {
        await auth.useAuthEmulator(
          environment.emulatorHost,
          9099,
          automaticHostMapping: false,
        );
        database.settings = const Settings(persistenceEnabled: false);
        database.useFirestoreEmulator(
          environment.emulatorHost,
          8080,
          automaticHostMapping: false,
        );
      } catch (_) {
        await app.delete();
        rethrow;
      }
    }
    return AppComposition.firebase(auth: auth, firestore: database);
  }
}
