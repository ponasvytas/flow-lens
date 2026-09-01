import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cloud_sessions.dart';
import 'session_repository_support.dart';

abstract interface class TrackingSessionRepository {
  Future<CloudTrackingSession> create(TrackingSessionDraft draft);

  Future<CloudTrackingSession> update(
    String sessionId,
    TrackingSessionDraft draft,
  );

  Future<List<CloudTrackingSession>> list({bool includeArchived = false});

  Future<CloudTrackingSession> load(String sessionId);

  Future<void> archive(String sessionId);

  Future<void> delete(String sessionId);
}

class FirestoreTrackingSessionRepository implements TrackingSessionRepository {
  FirestoreTrackingSessionRepository({
    required FirebaseFirestore firestore,
    required String? Function() userId,
    required bool Function() canSave,
  }) : _firestore = firestore,
       _userId = userId,
       _canSave = canSave;

  final FirebaseFirestore _firestore;
  final String? Function() _userId;
  final bool Function() _canSave;

  @override
  Future<CloudTrackingSession> create(TrackingSessionDraft draft) async {
    final userId = _requireUser();
    final content = draft.toContentMap();
    SessionDocumentSize.validate(content);
    final reference = _collection(userId).doc();
    await reference.set({
      ...content,
      'sessionId': reference.id,
      'ownerType': 'user',
      'ownerId': userId,
      'createdByUserId': userId,
      'updatedByUserId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'archivedAt': null,
    });
    return load(reference.id);
  }

  @override
  Future<CloudTrackingSession> update(
    String sessionId,
    TrackingSessionDraft draft,
  ) async {
    final userId = _requireUser();
    final content = draft.toContentMap();
    SessionDocumentSize.validate(content);
    await _collection(userId).doc(sessionId).set({
      ...content,
      'sessionId': sessionId,
      'updatedByUserId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return load(sessionId);
  }

  @override
  Future<List<CloudTrackingSession>> list({
    bool includeArchived = false,
  }) async {
    final userId = _requireUser();
    Query<Map<String, dynamic>> query = _collection(userId);
    if (!includeArchived) {
      query = query.where('archivedAt', isNull: true);
    }
    final snapshot = await query
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map(_fromSnapshot).toList(growable: false);
  }

  @override
  Future<CloudTrackingSession> load(String sessionId) async {
    final userId = _requireUser();
    final snapshot = await _collection(userId).doc(sessionId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Tracking session not found.');
    }
    return _fromSnapshot(snapshot);
  }

  @override
  Future<void> archive(String sessionId) async {
    final userId = _requireUser();
    await _collection(userId).doc(sessionId).update({
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUserId': userId,
    });
  }

  @override
  Future<void> delete(String sessionId) async {
    final userId = _requireUser();
    await _collection(userId).doc(sessionId).delete();
  }

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users/$userId/trackingSessions');

  String _requireUser() {
    final userId = _userId();
    if (!_canSave() || userId == null || userId.isEmpty) {
      throw const SessionAccessException(
        'An active premium account is required for cloud sessions.',
      );
    }
    return userId;
  }

  CloudTrackingSession _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = Map<String, dynamic>.from(snapshot.data()!);
    data['createdAt'] = _date(data['createdAt']);
    data['updatedAt'] = _date(data['updatedAt']);
    data['archivedAt'] = _nullableDate(data['archivedAt']);
    return CloudTrackingSession.fromMap(snapshot.id, data);
  }
}

DateTime _date(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  _ => DateTime.fromMillisecondsSinceEpoch(0),
};

DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);
