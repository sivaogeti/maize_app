import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  manager,
  territory_incharge,
  cluster_incharge,
  field_incharge,
  customer_support,
  admin,
}

String roleToString(UserRole r) => r.name;
UserRole roleFromString(String v) =>
    UserRole.values.firstWhere((e) => e.name == v, orElse: () => UserRole.field_incharge);

class AppUserProfile {
  final String uid;
  final String? displayName;
  final String role;

  // direct parents (nullable depending on role)
  final String? managerUid;
  final String? territoryInchargeUid;
  final String? clusterInchargeUid;

  /// flattened ancestor chain (include self uid as the last element)
  final List<String> orgPathUids;

  /// convenience flag: Admin / Customer Support (or “global” manager)
  final bool isSuper;

  AppUserProfile({
    required this.uid,
    required this.role,
    this.displayName,
    this.managerUid,
    this.territoryInchargeUid,
    this.clusterInchargeUid,
    List<String>? orgPathUids,         // optional param
    this.isSuper = false,
  }) : orgPathUids = (orgPathUids ?? const <String>[]);

  // NOTE: lowercase 'fromMap'
  factory AppUserProfile.fromMap(Map<String, dynamic> d, String uid) {
    return AppUserProfile(
      uid: d['uid'] as String? ?? uid,
      displayName: d['displayName'] as String?,
      role: (d['role'] ?? '').toString(),                        // fixed 'role' key
      managerUid: d['managerUid'] as String?,
      territoryInchargeUid: d['territoryInchargeUid'] as String?,
      clusterInchargeUid: d['clusterInchargeUid'] as String?,
      orgPathUids: (d['orgPathUids'] as List? ?? const []).cast<String>(),
      isSuper: d['super'] == true,                                // map Firestore "super" -> model isSuper
    );
  }

  /// Build org path from role + parents (always end with self uid)
  static List<String> buildOrgPath({
    required UserRole role,
    required String selfUid,
    String? managerUid,
    String? territoryInchargeUid,
    String? clusterInchargeUid,
    bool isSuper = false,
  }) {
    // Super roles can see all; we still include self for consistency.
    if (isSuper || role == UserRole.admin || role == UserRole.customer_support) {
      return [selfUid];
    }
    switch (role) {
      case UserRole.manager:
        return [selfUid];
      case UserRole.territory_incharge:
        return [if (managerUid != null) managerUid, selfUid];
      case UserRole.cluster_incharge:
        return [
          if (managerUid != null) managerUid,
          if (territoryInchargeUid != null) territoryInchargeUid,
          selfUid,
        ];
      case UserRole.field_incharge:
        return [
          if (managerUid != null) managerUid,
          if (territoryInchargeUid != null) territoryInchargeUid,
          if (clusterInchargeUid != null) clusterInchargeUid,
          selfUid,
        ];
      case UserRole.customer_support:
      case UserRole.admin:
        return [selfUid];
    }
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'role': role,
    'managerUid': managerUid,
    'territoryInchargeUid': territoryInchargeUid,
    'clusterInchargeUid': clusterInchargeUid,
    'orgPathUids': orgPathUids,
    'super': isSuper,
  };

  factory AppUserProfile.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return AppUserProfile(
      uid: d['uid'] as String,
      displayName: d['displayName'] as String?,
      role: (d['role'] ?? '').toString(),
      managerUid: d['managerUid'] as String?,
      territoryInchargeUid: d['territoryInchargeUid'] as String?,
      clusterInchargeUid: d['clusterInchargeUid'] as String?,
      orgPathUids: (d['orgPathUids'] as List? ?? const <dynamic>[]).cast<String>(),
      isSuper: d['super'] == true,
    );
  }

}
