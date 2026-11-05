import 'package:flutter/foundation.dart';
import '../models/challenge.dart';
import '../services/challenge_repository.dart';

class ChallengesController extends ChangeNotifier {
  ChallengesController(this.repository);
  final ChallengeRepository repository;
  List<ChallengeSummary> _items = const [];
  List<ChallengeSummary> get items => _items;
  ChallengeDetail? detail;
  bool busy = false;
  String? error;
  bool _disposed = false;

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return !_disposed;
    } catch (e) {
      if (!_disposed) error = e.toString();
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> refresh() => _run(() async {
    final result = await repository.request({'action': 'list'});
    if (!_disposed) {
      _items = List.unmodifiable(
        (result['challenges'] as List).map(
          (c) => ChallengeSummary.fromJson(challengeMap(c)),
        ),
      );
    }
  });

  Future<bool> execute(Map<String, dynamic> request) => _run(() async {
    final result = await repository.request(request);
    if (!_disposed) detail = ChallengeDetail.fromJson(result);
  });

  Future<bool> open(String id) => execute({'action': 'get', 'id': id});
  Future<bool> join(ChallengeInvitation invitation) => execute({
    'action': 'join',
    'id': invitation.id,
    'token': invitation.token,
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
