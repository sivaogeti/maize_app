import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user_profile.dart';

class UserService {
  UserService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');

  Future<AppUserProfile?> getProfile(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return AppUserProfile.fromSnap(doc);
  }

  /// Create the user doc if it doesn't exist yet.
  /// Call this right after sign-in/registration.
  Future<void> ensureUserDoc({
    required String uid,
    required String displayName,
    required UserRole role,
    String? managerUid,
    String? territoryInchargeUid,
    String? clusterInchargeUid,
    bool isSuper = false,
  }) async {
    final ref = _col.doc(uid);
    final snap = await ref.get();
    if (snap.exists) return; // already present

    final path = AppUserProfile.buildOrgPath(
      role: role,
      selfUid: uid,
      managerUid: managerUid,
      territoryInchargeUid: territoryInchargeUid,
      clusterInchargeUid: clusterInchargeUid,
      isSuper: isSuper,
    );

    final prof = AppUserProfile(
      uid: uid,
      displayName: displayName,
      role: role,
      managerUid: managerUid,
      territoryInchargeUid: territoryInchargeUid,
      clusterInchargeUid: clusterInchargeUid,
      orgPathUids: path,
      isSuper: isSuper,
    );

    await ref.set(prof.toMap(), SetOptions(merge: true));
  }

  /// If you later change parents/role, call this to recompute orgPathUids.
  Future<void> updateParents({
    required String uid,
    required UserRole role,
    String? managerUid,
    String? territoryInchargeUid,
    String? clusterInchargeUid,
    bool? isSuper,
  }) async {
    final ref = _col.doc(uid);
    final doc = await ref.get();
    final cur = doc.exists ? AppUserProfile.fromSnap(doc) : null;
    final superFlag = isSuper ?? cur?.isSuper ?? false;

    final path = AppUserProfile.buildOrgPath(
      role: role,
      selfUid: uid,
      managerUid: managerUid,
      territoryInchargeUid: territoryInchargeUid,
      clusterInchargeUid: clusterInchargeUid,
      isSuper: superFlag,
    );

    await ref.set({
      'role': roleToString(role),
      'managerUid': managerUid,
      'territoryInchargeUid': territoryInchargeUid,
      'clusterInchargeUid': clusterInchargeUid,
      'orgPathUids': path,
      'super': superFlag,
    }, SetOptions(merge: true));
  }
}
