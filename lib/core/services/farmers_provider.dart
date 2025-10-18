import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar_community/isar.dart' as _db;

import 'auth_service.dart';

import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/farmer.dart';

import 'package:firebase_auth/firebase_auth.dart';



class FarmersProvider extends ChangeNotifier {
  FarmersProvider(this._db) {
    _bindStream();
  }

  final FirebaseFirestore _db;

  List<Farmer> _farmers = [];
  List<Farmer> get farmers => _farmers;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void _bindStream() {
    _sub?.cancel();
    _sub = _db
        .collection('farmers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _farmers = snap.docs.map(Farmer.fromDoc).toList(growable: false);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  final Map<String, Farmer> _byId = <String, Farmer>{};

  UnmodifiableListView<Farmer> get items =>
      UnmodifiableListView<Farmer>(_byId.values);

// Call when you have a Farmer instance
  void addOrUpdate(Farmer farmer) {
    _byId[farmer.id] = farmer;
    notifyListeners();
  }

// Call when you have a Map (from Firestore or UI)
  void addOrUpdateFromMap(Map<String, dynamic> map) {
    final farmer = Farmer.fromMap(map);
    _byId[farmer.id] = farmer;
    notifyListeners();
  }

// (Optional—but harmless if somewhere else still calls it)
  Future<void> refresh() async {
    // No-op refresh to avoid build errors if older code still calls refresh()
    notifyListeners();
  }


  Future<void> fetchAll(FirebaseFirestore db) async {
    final snap = await db.collection('farmers').orderBy('createdAt', descending: true).get();
    _farmers = snap.docs.map((d) => Farmer.fromMap(d.data())).toList();
    notifyListeners();
  }


  /// Transaction to allocate the next global suffix.
  Future<int> _nextSuffix() async {
    final ref = _db.collection('counters').doc('farmers');
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      int next = 1;
      if (snap.exists) next = (snap.data()?['next'] as int?) ?? 1;
      tx.set(ref, {'next': next + 1}, SetOptions(merge: true));
      return next;
    });
  }

  String _slug(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');


  /// --- Compatibility methods (so old code compiles) ---

  /// Old code calls this; we just upsert the doc.
  Future<void> addFarmer(Farmer f) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid  = user?.uid ?? 'anon';

    final map = f.toMap();
    map['createdBy']   = map['createdBy'] ?? uid;
    map['orgPathUids'] = (map['orgPathUids'] as List?) ?? [uid];

    await _db.collection( 'farmers').doc(f.id).set(f.toMap(), SetOptions(merge: true));
  }

  /// Old code calls this to delete.
  Future<void> removeFarmer(String frId) async {
    await _db.collection('farmers').doc(frId).delete();
  }

  // lib/core/services/farmers_provider.dart

// Alias so older screens that call `.sorted` keep working.
  Iterable<dynamic> get sorted {
    // prefer whatever you actually expose; adjust the order if needed
    final dynamic self = this;
    if ((self as dynamic).farmers != null) return (self as dynamic).farmers as Iterable;
    if ((self as dynamic).views   != null) return (self as dynamic).views   as Iterable;
    if ((self as dynamic).list    != null) return (self as dynamic).list    as Iterable;
    return const <dynamic>[];
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _farmersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // return an empty stream if somehow not signed in
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    // If you saved `orgPathUids` on each doc (you do), this matches your rules.
    return _db
        .collection('farmers')
        .where('orgPathUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }


}
