import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import 'fied_incharge_list_details_screen.dart';

/*final testUid = '<one FI uid that should be visible>';
final d = await FirebaseFirestore.instance.doc('users/$testUid').get();
print('can read: ${d.exists}');*/


class FieldInchargesScreen extends StatelessWidget {
  const FieldInchargesScreen({super.key});


  @override
  Widget build(BuildContext context) {
    // query: users with role field_incharge and in same org path
    final auth  = context.read<AuthService>();
    final cicUid = auth.currentUser!.uid; // or your helper

    // List<String>
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'field_incharge')
        .where('orgPathUids', arrayContains: cicUid)
        .orderBy('displayName');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Incharge Details'),
        leading: const BackButton(), // back
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (!context.mounted) return;
              // GoRouter:
              context.go('/login');
              // (If you use Navigator 1.0 instead)
              // Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Error loading FICs', style: TextStyle(color: Colors.red)),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No Field Incharges found'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final uid   = d['uid'] as String? ?? docs[i].id;
              final name  = d['displayName'] as String? ?? 'Unknown';
              final phone = d['phone'] as String? ?? '';

              return Material(                     // <-- add this wrapper
                color: Theme.of(context).cardColor, // optional, keeps card look
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(name),
                  subtitle: Text(uid),
                  onTap: () => context.push('/cic/field-incharge/$uid'),
                ),
              );
            },
          );
        },
      ),
    );
  }

}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg)));
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    ),
  );
}
