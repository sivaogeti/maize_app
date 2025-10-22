import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';

class FieldInchargeDetailScreen extends StatefulWidget {
  final String uid;

  const FieldInchargeDetailScreen({
    Key? key,
    required this.uid,
  }) : super(key: key);

  @override
  State<FieldInchargeDetailScreen> createState() =>
      _FieldInchargeDetailScreenState();
}

class _FieldInchargeDetailScreenState extends State<FieldInchargeDetailScreen> {
  late final DocumentReference<Map<String, dynamic>> _fiDoc =
  FirebaseFirestore.instance.collection('users').doc(widget.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Incharge Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/cic/field-incharges');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fiDoc.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Field Incharge not found.'));
          }

          final data = snap.data!.data()!;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final createdStr = createdAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
              : '—';

          Widget info(String label, String? value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 130,
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                Expanded(child: Text(value ?? '—')),
              ],
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              info('Display Name', data['displayName']),
              info('Phone', data['phone']),
              info('Email', data['email']),
              info('Role', data['role']),
              info('Cluster Incharge UID', data['clusterInchargeUid']),
              info('Created At', createdStr),
              info('Address', data['address']),
              info('Org Path', (data['orgPathUids'] ?? []).join(', ')),
              const SizedBox(height: 20),
              const Divider(),
              Center(
                child: Text(
                  'End of details',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
