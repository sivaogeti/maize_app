import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/farmer.dart';

class FarmersRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Normalizes strings for the FR id (spaces -> underscore, lowercase).
  String _slug(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  /// Transactional counter per (village, name) pair.
  /// Creates/updates doc: counters/farmerIds/FR_<v>_<n>
  Future<int> _nextSequence(String village, String name) async {
    final v = _slug(village);
    final n = _slug(name);
    final key = 'FR_${v}_${n}';
    final ref = _db.collection('counters').doc('farmerIds').collection('seq').doc(key);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      int next = 1;
      if (snap.exists) {
        next = (snap.data()?['next'] ?? 1) as int;
      }
      tx.set(ref, {'next': next + 1}, SetOptions(merge: true));
      return next;
    });
  }

  Future<String> generateFarmerId(String village, String name) async {
    final v = _slug(village);
    final n = _slug(name);
    final seq = await _nextSequence(village, name);
    return 'FR_${v}_${n}_$seq';
  }

  Future<String> _uploadBytes(String path, Uint8List bytes, {String contentType = 'image/png'}) async {
    final task = await _storage.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    return task.ref.getDownloadURL();
  }

  Future<String> _uploadFile(String path, File file, {String contentType = 'image/jpeg'}) async {
    final task = await _storage.ref(path).putFile(file, SettableMetadata(contentType: contentType));
    return task.ref.getDownloadURL();
  }

  /// Create or update a farmer; returns the id used.
  Future<String> upsertFarmer({
    required String name,
    required String phone,
    required String cropVillage,
    required String cluster,
    required String territory,
    required String season,
    required String hybrid,
    required num proposedArea,
    required String waterSource,
    required String previousCrop,
    required String soilType,
    required String createdBy,
    String? existingId,                 // pass when editing
    File? photoFile,                    // optional
    Uint8List? signaturePng,            // optional
  }) async {
    final id = existingId ?? await generateFarmerId(cropVillage, name);

    String? photoUrl;
    String? signatureUrl;

    if (photoFile != null) {
      photoUrl = await _uploadFile('farmers/$id/photo.jpg', photoFile);
    }
    if (signaturePng != null) {
      signatureUrl = await _uploadBytes('farmers/$id/signature.png', signaturePng);
    }

    final doc = _db.collection('farmers').doc(id);

    await doc.set({
      'id': id,
      'name': name,
      'phone': phone,
      'cropVillage': cropVillage,
      'cluster': cluster,
      'territory': territory,
      'season': season,
      'hybrid': hybrid,
      'proposedArea': proposedArea,
      'waterSource': waterSource,
      'previousCrop': previousCrop,
      'soilType': soilType,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (signatureUrl != null) 'signatureUrl': signatureUrl,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return id;
  }

  Stream<List<Farmer>> streamFarmersForUser(String uid) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';

    return _db.collection('farmers')
        .where('orgPathUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Farmer.fromMap(d.data())).toList());
  }

// If you want "all" farmers, use without the where clause (or filter by role/cluster).
}
