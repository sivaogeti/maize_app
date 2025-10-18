import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar_community/isar.dart' hide Query; // keep 'hide Query' where Firestore is also imported
import '../local/isar_service.dart';
import '../models/farmer.dart';
import '../remote/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class FarmerRepository {
  final _isar = IsarService.instance.db;
  final _fs = FirestoreService.instance;
  final _auth = FirebaseAuth.instance;

  String get orgId {
    // TODO: read from custom claims or secure storage
    return 'ORG1';
  }

  Future<void> upsertLocal(FarmerLocal f, {bool pending = false}) async {
    await _isar.writeTxn(() async {
      f.pending = pending ? true : f.pending;
      await _isar.farmerLocals.put(f);
    });
  }

  Stream<List<FarmerLocal>> watchLocal() {
    return _isar.farmerLocals
        .where()
        .filter()
        .deletedEqualTo(false)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> pushPending() async {
    final pendings = await _isar.farmerLocals.filter().pendingEqualTo(true).findAll();
    for (final f in pendings) {
      final data = {
        'name': f.name,
        'phone': f.phone,
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': f.deleted,
      };
      final docId = f.farmerId.isNotEmpty ? f.farmerId : _fs.farmersCol(orgId).doc().id;
      await _fs.farmersCol(orgId).doc(docId).set(data, SetOptions(merge: true));
      await _isar.writeTxn(() async {
        f.farmerId = docId;
        f.pending = false;
        f.updatedAt = DateTime.now();
        await _isar.farmerLocals.put(f);
      });
    }
  }

  Future<void> pullSince(DateTime? since) async {
    Query<Map<String, dynamic>> q = _fs.farmersCol(orgId).where('deleted', isEqualTo: false);
    if (since != null) {
      q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await q.get();
    await _isar.writeTxn(() async {
      for (final d in snap.docs) {
        final m = d.data();
        final f = FarmerLocal()
          ..farmerId = d.id
          ..orgId = orgId
          ..name = (m['name'] ?? '') as String
          ..phone = (m['phone'] as String?)
          ..updatedAt = (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          ..deleted = (m['deleted'] ?? false) as bool
          ..pending = false;
        await _isar.farmerLocals.put(f);
      }
    });
  }
}
