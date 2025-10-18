import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> farmersCol(String orgId) =>
      _db.collection('orgs').doc(orgId).collection('farmers');

  CollectionReference<Map<String, dynamic>> registrationsCol(String orgId) =>
      _db.collection('orgs').doc(orgId).collection('registrations');
}
