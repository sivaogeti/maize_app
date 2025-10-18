import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar_community/isar.dart' hide Query; // keep 'hide Query' where Firestore is also imported
import '../local/isar_service.dart';
import '../models/registration.dart';
import '../remote/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class RegistrationRepository {
  final _isar = IsarService.instance.db;
  final _fs = FirestoreService.instance;
  final _auth = FirebaseAuth.instance;

  String get orgId {
    // TODO: read from custom claims or secure storage
    return 'ORG1';
  }

  Future<void> upsertLocal(RegistrationLocal r, {bool pending = false}) async {
    await _isar.writeTxn(() async {
      r.pending = pending ? true : r.pending;
      await _isar.registrationLocals.put(r);
    });
  }

  Stream<List<RegistrationLocal>> watchLocal() {
    return _isar.registrationLocals
        .where()
        .filter()
        .deletedEqualTo(false)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> pushPending() async {
    final pendings = await _isar.registrationLocals.filter().pendingEqualTo(true).findAll();
    for (final r in pendings) {
      final data = {
        'farmerId': r.farmerId,
        'notes': r.notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': r.deleted,
      };
      final docId = r.regId.isNotEmpty ? r.regId : _fs.registrationsCol(orgId).doc().id;
      await _fs.registrationsCol(orgId).doc(docId).set(data, SetOptions(merge: true));
      await _isar.writeTxn(() async {
        r.regId = docId;
        r.pending = false;
        r.updatedAt = DateTime.now();
        await _isar.registrationLocals.put(r);
      });
    }
  }

  Future<void> pullSince(DateTime? since) async {
    Query<Map<String, dynamic>> q = _fs.registrationsCol(orgId).where('deleted', isEqualTo: false);
    if (since != null) {
      q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await q.get();
    await _isar.writeTxn(() async {
      for (final d in snap.docs) {
        final m = d.data();
        final r = RegistrationLocal()
          ..regId = d.id
          ..orgId = orgId
          ..farmerId = (m['farmerId'] ?? '') as String
          ..notes = (m['notes'] as String?)
          ..updatedAt = (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
          ..deleted = (m['deleted'] ?? false) as bool
          ..pending = false;
        await _isar.registrationLocals.put(r);
      }
    });
  }
}
