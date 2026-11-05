import 'package:flow_lens/app/backend_environment.dart';
import 'package:flow_lens/services/challenge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('local mode cannot inherit production API or sharing overrides', () {
    const environment = BackendEnvironment(
      useEmulators: true,
      apiOverride: 'https://production.example/api',
      shareOverride: 'https://production.example/',
    );
    expect(
      environment.challengeEndpoint('production-project').toString(),
      'http://127.0.0.1:5001/demo-flow-lens-challenges/us-central1/challenges',
    );
    expect(environment.shareRoot().toString(), 'http://127.0.0.1:54321/');
    expect(BackendEnvironment.demoOptions.projectId, startsWith('demo-'));
    expect(
      environment
          .shareRoot(browserUri: Uri.parse('https://production.example/'))
          .host,
      '127.0.0.1',
    );
  });

  test('local invitations preserve the local browser host and port only', () {
    const environment = BackendEnvironment(useEmulators: true);
    expect(
      environment
          .shareRoot(
            browserUri: Uri.parse(
              'http://localhost:6000/?challenge=old#invite=old',
            ),
          )
          .toString(),
      'http://localhost:6000/',
    );
  });

  test('production defaults and explicit overrides remain available', () {
    const production = BackendEnvironment();
    expect(
      production.challengeEndpoint('flow-lens-3f987').toString(),
      'https://us-central1-flow-lens-3f987.cloudfunctions.net/challenges',
    );
    expect(production.shareRoot().host, 'flow-lens-player.web.app');
    const staging = BackendEnvironment(
      apiOverride: 'https://staging.example/api',
      shareOverride: 'https://staging.example/',
    );
    expect(
      staging.challengeEndpoint('project').toString(),
      'https://staging.example/api',
    );
    expect(staging.shareRoot().host, 'staging.example');
  });

  test(
    'missing emulator reports the actionable local startup instruction',
    () async {
      for (final status in [404, null]) {
        final repository = FirebaseChallengeRepository.withTransport(
          endpoint: Uri.parse(
            'http://127.0.0.1:5001/demo-flow-lens-challenges/us-central1/challenges',
          ),
          token: () async => 'local-token',
          localBackend: true,
          post: (uri, {headers, body, encoding}) async {
            if (status == null) {
              throw http.ClientException('Connection refused');
            }
            return http.Response('Missing', status);
          },
        );
        await expectLater(
          repository.request({'action': 'list'}),
          throwsA(
            isA<ChallengeException>().having(
              (e) => e.message,
              'message',
              contains('Start the local backend'),
            ),
          ),
        );
      }
    },
  );
}
