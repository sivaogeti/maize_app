import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One item as shown in the list (keeps both doc + data)
class FieldObservationView {
  final String id;
  final Map<String, dynamic> data;
  FieldObservationView(this.id, this.data);
}

class FieldObservationsProvider with ChangeNotifier {
  FieldObservationsProvider(this._db);

  final FirebaseFirestore _db;

  /// public, read-only list you can bind your UI to
  List<FieldObservationView> _items = [];
  List<FieldObservationView> get items => _items;

  StreamSubscription? _sub;

  /// Begin listening to collection
  void bind() {
    _sub?.cancel();
    _sub = _db
        .collection('field_observations')
        .orderBy('date', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      _items = snap.docs
          .map((d) => FieldObservationView(d.id, d.data()))
          .toList(growable: false);
      notifyListeners();
    });
  }

  /// Stop listening (optional)
  void unbind() {
    _sub?.cancel();
    _sub = null;
  }

  /// Create a new document
  Future<void> addObservation(Map<String, dynamic> payload) async {
    await _db.collection('field_observations').add(payload);
  }
}