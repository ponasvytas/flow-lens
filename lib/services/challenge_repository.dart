import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/challenge.dart';
import '../app/backend_environment.dart';

abstract interface class ChallengeRepository {
  Future<Map<String, dynamic>> request(Map<String, dynamic> data);
}

class ChallengeException implements Exception {
  const ChallengeException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FirebaseChallengeRepository implements ChallengeRepository {
  FirebaseChallengeRepository(FirebaseAuth auth)
    : this.withTransport(
        token: () async => auth.currentUser?.getIdToken(),
        endpoint: BackendEnvironment.current.challengeEndpoint(
          auth.app.options.projectId,
        ),
        localBackend: BackendEnvironment.current.useEmulators,
      );

  FirebaseChallengeRepository.withTransport({
    required this.token,
    required this.endpoint,
    this.post = http.post,
    this.localBackend = false,
  });

  final Future<String?> Function() token;
  final Uri endpoint;
  final bool localBackend;
  final Future<http.Response> Function(
    Uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  })
  post;

  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> data) async {
    try {
      final idToken = await token();
      if (idToken == null) {
        throw const ChallengeException('Sign in to use challenges.');
      }
      final response = await post(
        endpoint,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': data}),
      ).timeout(const Duration(seconds: 40));
      if (response.statusCode == 404) {
        throw ChallengeException(
          localBackend
              ? 'The local challenge service is unavailable. Start the local backend and retry.'
              : 'The challenge service has not been deployed yet.',
        );
      }
      final body = challengeMap(jsonDecode(response.body));
      if (body['error'] case final Map error) {
        throw ChallengeException(
          error['message'] as String? ?? 'The request could not be completed.',
        );
      }
      if (response.statusCode != 200 || body['result'] is! Map) {
        throw const ChallengeException(
          'Challenges are temporarily unavailable. Please retry.',
        );
      }
      return challengeMap(body['result']);
    } on ChallengeException {
      rethrow;
    } on TimeoutException {
      throw const ChallengeException(
        'The request timed out. Retry to check whether it completed.',
      );
    } catch (_) {
      throw ChallengeException(
        localBackend
            ? 'Could not reach the local challenge service. Start the local backend and retry.'
            : 'Could not reach the challenge service. It may be offline or not yet deployed.',
      );
    }
  }
}

String newChallengeRequestId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
