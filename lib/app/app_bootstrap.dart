import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../utils/app_log.dart';
import 'app_composition.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppComposition> create() async {
    try {
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
}
