// ...imports...
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';   // adjust path if different

class FieldInchargeDetailScreen extends StatelessWidget {
  final String uid;
  const FieldInchargeDetailScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Incharge Details'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading FICs', style: TextStyle(color: Colors.red)));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!.data()!;
          // render whatever fields you want
          return ListView(
            children: [
              ListTile(title: Text(d['displayName'] ?? '')),
              ListTile(title: Text('UID: $uid')),
              // more fields...
            ],
          );
        },
      ),
    );
  }
}



  Widget _kv(String k, String v) => ListTile(
    dense: true,
    leading: const Icon(Icons.info_outline),
    title: Text(k),
    subtitle: Text(v.isEmpty ? '—' : v),
  );


/// tiny inline replacements for the old helpers
class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    ),
  );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}
