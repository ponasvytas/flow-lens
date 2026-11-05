import 'package:firebase_core/firebase_core.dart';

/// One switch routes all account and challenge services to the same backend.
class BackendEnvironment {
  const BackendEnvironment({
    this.useEmulators = false,
    this.emulatorHost = '127.0.0.1',
    this.apiOverride = '',
    this.shareOverride = '',
  });

  static const current = BackendEnvironment(
    useEmulators: bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    emulatorHost: String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    ),
    apiOverride: String.fromEnvironment('CHALLENGE_API_URL'),
    shareOverride: String.fromEnvironment('CHALLENGE_SHARE_URL'),
  );

  static const demoProjectId = 'demo-flow-lens-challenges';
  static const demoAppName = 'flow-lens-local';
  static const demoOptions = FirebaseOptions(
    apiKey: 'local-emulator-key',
    appId: '1:1234567890:web:0000000000000000000000',
    messagingSenderId: '1234567890',
    projectId: demoProjectId,
  );

  final bool useEmulators;
  final String emulatorHost;
  final String apiOverride;
  final String shareOverride;

  Uri challengeEndpoint(String productionProjectId) => useEmulators
      ? Uri(
          scheme: 'http',
          host: emulatorHost,
          port: 5001,
          path: '/$demoProjectId/us-central1/challenges',
        )
      : Uri.parse(
          apiOverride.isNotEmpty
              ? apiOverride
              : 'https://us-central1-$productionProjectId.cloudfunctions.net/challenges',
        );

  Uri shareRoot({Uri? browserUri}) {
    if (useEmulators) {
      if (browserUri != null &&
          browserUri.scheme == 'http' &&
          [
            emulatorHost,
            'localhost',
            '127.0.0.1',
            '::1',
          ].contains(browserUri.host)) {
        return Uri(
          scheme: browserUri.scheme,
          host: browserUri.host,
          port: browserUri.port,
          path: '/',
        );
      }
      return Uri(scheme: 'http', host: emulatorHost, port: 54321, path: '/');
    }
    return Uri.parse(
      shareOverride.isNotEmpty
          ? shareOverride
          : 'https://flow-lens-player.web.app/',
    );
  }
}
