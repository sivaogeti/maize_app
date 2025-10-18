import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart'; // adjust if your path differs

class FieldDiagnosticsDetailsScreen extends StatelessWidget {
  const FieldDiagnosticsDetailsScreen({super.key});

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid; // <-- your AppUser has `id`, not `uid`

    final q = FirebaseFirestore.instance
        .collection('field_diagnostics')
        .where('orgPathUids', arrayContains: uid) // subtree visibility
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => (context as Element).markNeedsBuild(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading diagnostics:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No diagnostics yet'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();

              // date
              DateTime dt;
              final rawDate = d['createdAt'] ?? d['date'];
              if (rawDate is Timestamp) {
                dt = rawDate.toDate();
              } else if (rawDate is DateTime) {
                dt = rawDate;
              } else {
                dt = DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
              }

              final dateStr = _ymd(dt);
              final farmerId = (d['farmerOrFieldId'] ?? '').toString().trim();
              final cropStage = (d['cropStage'] ?? '').toString().trim();
              final issue = (d['issue'] ?? '').toString().trim();
              final rec = (d['recommendation'] ?? '').toString().trim();

              return ListTile(
                leading: const Icon(Icons.healing_outlined),
                title: Text(issue.isEmpty ? '(no issue text)' : issue),
                subtitle: Text(
                  [
                    dateStr,
                    if (farmerId.isNotEmpty) farmerId,
                    if (cropStage.isNotEmpty) cropStage,
                  ].join('  •  '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _DiagSheet(
                    data: {
                      'Date': dateStr,
                      'Farmer / Field ID': farmerId,
                      'Crop & Stage': cropStage,
                      'Issue / Observation': issue,
                      'Recommendation / Next action': rec,
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DiagSheet extends StatelessWidget {
  const _DiagSheet({required this.data});
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => e.value.trim().isNotEmpty).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(e.value),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
