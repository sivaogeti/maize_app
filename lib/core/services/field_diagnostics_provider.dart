import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection name
const String kFieldDiagnosticsCollection = 'field_diagnostics';

/// A tiny model to expose id + data together.
@immutable
class DiagnosticItem {
  final String id;
  final Map<String, dynamic> data;
  const DiagnosticItem(this.id, this.data);
}

/// ChangeNotifier that reads/writes the `field_diagnostics` collection.
class FieldDiagnosticsProvider extends ChangeNotifier {
  FieldDiagnosticsProvider(this._db);

  final FirebaseFirestore _db;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _boundUserId;

  /// In-memory list of documents ordered by createdAt desc.
  List<DiagnosticItem> _items = const [];
  List<DiagnosticItem> get items => _items;

  /// Start (or restart) listening to the collection.
  /// If [userId] is provided, results are filtered to docs created by that user.
  void bind({required String viewerUid}) {
    _boundUserId = viewerUid;
    _sub?.cancel();

    Query<Map<String, dynamic>> q = _db
        .collection(kFieldDiagnosticsCollection)
        .where('orgPathUids', arrayContains: viewerUid)
        .orderBy('createdAt', descending: true);

    _sub = q.snapshots().listen((snap) {
      _items = snap.docs.map((d) => DiagnosticItem(d.id, d.data())).toList(growable: false);
      notifyListeners();
    });
  }


  /// Stop listening (call from dispose of your root provider if needed).
  Future<void> unbind() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Create a new diagnostic entry. Returns the new document id.
  Future<String> add(Map<String, dynamic> payload, {String? forceId}) async {
    final data = <String, dynamic>{
      ...payload,
      // fill on the server if caller didn’t send them
      'createdAt': payload['createdAt'] ?? FieldValue.serverTimestamp(),
      if (!_hasKey(payload, 'createdBy') && _boundUserId != null)
        'createdBy': _boundUserId,
    };

    final ref = forceId == null
        ? _db.collection(kFieldDiagnosticsCollection).doc()
        : _db.collection(kFieldDiagnosticsCollection).doc(forceId);

    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  /// Update an existing diagnostic.
  Future<void> update(String id, Map<String, dynamic> changes) {
    return _db
        .collection(kFieldDiagnosticsCollection)
        .doc(id)
        .update(changes);
  }

  /// Delete a diagnostic.
  Future<void> remove(String id) {
    return _db
        .collection(kFieldDiagnosticsCollection)
        .doc(id)
        .delete();
  }

  /// Helper to build a consistent document payload.
  static Map<String, dynamic> buildEntry({
    required DateTime date,
    required String farmerOrFieldId,
    String cropStage = '',
    String issue = '',
    String recommendation = '',
    double? lat,
    double? lng,
    double? distanceKm,
    List<String> photoPaths = const [],
    String? createdBy,
    DateTime? createdAt,
  }) {
    return <String, dynamic>{
      'date': Timestamp.fromDate(date),
      'farmerOrFieldId': farmerOrFieldId,
      'cropStage': cropStage,
      'issue': issue,
      'recommendation': recommendation,
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (photoPaths.isNotEmpty) 'photoPaths': photoPaths,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool _hasKey(Map<String, dynamic> m, String k) {
    try {
      return m.containsKey(k);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
