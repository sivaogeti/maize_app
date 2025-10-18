import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Lightweight view model for a row in Inputs Details.
class InputIssueView {
  final String id;
  final String farmerOrFieldId;
  final String cropAndStage;
  final String itemType;
  final String brandOrGrade;
  final String batchOrLotNo;
  final String unitOfMeasure;
  final double quantityIssued;
  final DateTime dateOfIssue;
  final String? photoPath;
  final String? signaturePng;
  final String? createdBy;
  final Timestamp? createdAt;
  final Map<String, dynamic> raw;

  InputIssueView(this.id, Map<String, dynamic> m)
      : farmerOrFieldId = (m['farmerOrFieldId'] ?? '') as String,
        cropAndStage = (m['cropAndStage'] ?? '') as String,
        itemType = (m['itemType'] ?? '') as String,
        brandOrGrade = (m['brandOrGrade'] ?? '') as String,
        batchOrLotNo = (m['batchOrLotNo'] ?? '') as String,
        unitOfMeasure = (m['unitOfMeasure'] ?? '') as String,
        quantityIssued = (m['quantityIssued'] is num)
            ? (m['quantityIssued'] as num).toDouble()
            : 0.0,
        dateOfIssue = ((m['dateOfIssue'] as Timestamp?)?.toDate()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        photoPath = m['photoPath'] as String?,
        signaturePng = m['signaturePng'] as String?,
        createdBy = m['createdBy'] as String?,
        createdAt = m['createdAt'] as Timestamp?,
        raw = m;
}

class InputIssuesProvider extends ChangeNotifier {
  final FirebaseFirestore db;
  InputIssuesProvider(this.db);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<InputIssueView> _items = [];
  List<InputIssueView> get items => _items;

  /// Start listening to Firestore.
  void bind() {
    _sub?.cancel();
    _sub = db
        .collection('input_issues')
        .orderBy('dateOfIssue', descending: true)
    // .where('createdBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid) // optional per-user filter
        .snapshots()
        .listen((qs) {
      _items = qs.docs.map((d) => InputIssueView(d.id, d.data())).toList();
      notifyListeners();
    });
  }

  /// Called from Input Supply screen to persist a new row.
  Future<void> addIssue(Map<String, dynamic> payload) async {
    payload['createdAt'] ??= FieldValue.serverTimestamp();
    await db.collection('input_issues').add(payload);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
