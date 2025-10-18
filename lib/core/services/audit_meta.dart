import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_clean/core/services/auth_service.dart';

import 'auth_service.dart';


class AuditMeta {
  /// Returns the standard metadata to attach to every created/updated document.
  static Map<String, dynamic> build(AuthService auth) {
    final uid = auth.uid;
    final roleString = auth.roleOrUnknown;

    // org path must include the creator
    final List<String> path = [...auth.orgPathUidList];
    if (uid != null && !path.contains(uid)) path.add(uid);

    return <String, dynamic>{
      'createdBy': uid,
      'orgPathUids': path,
      'roleOfCreator': roleString,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
