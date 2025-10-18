import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

CollectionReference<Map<String, dynamic>> userLogsCol(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs');



class DailyLogsDetailsScreen extends StatelessWidget {
  final String docId;
  const DailyLogsDetailsScreen({super.key, required this.docId});

  DocumentReference<Map<String, dynamic>> _docRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users').doc(uid).collection('daily_logs')
        .doc(docId);
  }

  @override
  Widget build(BuildContext context) {
    final ref = _docRef();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('fi.daily.logs.list');
            }
          },
        ),
        actions: [
          // 1) Log out
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthService>().logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef().snapshots(),
        builder: (context, snap) {

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Daily log not found'));
          }

          final data = snap.data!.data()!;

          final ts = data['createdAt'];
          DateTime? created;
          if (ts is Timestamp) {
            created = ts.toDate();
          } else if (ts is String) {
            created = DateTime.tryParse(ts);
          }

          Widget row(String label, String? value, {int maxLines = 4}) => ListTile(
            title: Text(label, style: Theme.of(context).textTheme.labelMedium),
            subtitle: Text(
              (value == null || value.trim().isEmpty) ? '—' : value.trim(),
              maxLines: maxLines,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          );


          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kv('Date',          data['date']),
              _kv('Activities',    data['activities']),
              _kv('Farmer / Field',data['farmerId']),
              _kv('Planned Time',  data['plannedTime']),
              _kv('Actual Time',   data['actualTime']),
              _kv('Remarks',       data['remarks']),
              _kv('Inputs',        data['inputs']),
              _kv('Issues',        data['issues']),
              _kv('Next Action',   data['nextAction']),
              _kv('Created At', () {
                final ts = data['createdAt'];
                if (ts is Timestamp) return ts.toDate().toString();
                return ts?.toString();
              }()),
            ],
          );
        },
      ),

    );
  }

  String _fmtTs(Object? ts) {
    if (ts is Timestamp) return ts.toDate().toString();
    return '';
  }
}

// helper:
Widget _kv(String label, Object? value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text((value ?? '—').toString()),
    ],
  ),
);
