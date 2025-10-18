import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DailyLog {
  final String id;
  final DateTime date;
  final String activities;
  final String farmerOrFieldId;
  final String planTime;
  final String actualTime;
  final String remarks;
  final DateTime? createdAt;
  final String createdBy;

  DailyLog({
    required this.id,
    required this.date,
    required this.activities,
    required this.farmerOrFieldId,
    required this.planTime,
    required this.actualTime,
    required this.remarks,
    required this.createdBy,
    this.createdAt,
  });

  factory DailyLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};

    DateTime _toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
    }

    return DailyLog(
      id: doc.id,
      date: _toDate(d['date']),
      activities: (d['activities'] ?? '').toString(),
      farmerOrFieldId: (d['farmerOrFieldId'] ?? '').toString(),
      planTime: (d['planTime'] ?? '').toString(),
      actualTime: (d['actualTime'] ?? '').toString(),
      remarks: (d['remarks'] ?? '').toString(),
      createdBy: (d['createdBy'] ?? '').toString(),
      createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null,
    );
  }
}

class DailyLogsProvider extends ChangeNotifier {
  final FirebaseFirestore _db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  DailyLogsProvider(this._db);

  List<DailyLog> _logs = [];
  List<DailyLog> get logs => _logs;

  /// Start listening to Firestore. Pass a userId to filter per user.
  Future<void> bind({required String viewerUid}) async {
    await _sub?.cancel();

    Query<Map<String, dynamic>> q = _db
        .collection('daily_logs')
        .where('orgPathUids', arrayContains: viewerUid)
        .orderBy('createdAt', descending: true);

    _sub = q.snapshots().listen((snap) {
      _logs = snap.docs.map(DailyLog.fromDoc).toList();
      notifyListeners();
    });
  }

  Future<void> unbind() async {
    await _sub?.cancel();
    _sub = null;
    _logs = [];
    notifyListeners();
  }



  /// **Writes** one log to Firestore and returns the new id.
  Future<String> addLog(Map<String, dynamic> payload) async {
    payload['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _db.collection('daily_logs').add(payload);
    return ref.id;
  }

  Future<void> deleteLog(String id) =>
      _db.collection('daily_logs').doc(id).delete();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
