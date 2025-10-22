// lib/features/cluster/cluster_daily_logs_details_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

String _fmtDateFlexible(dynamic v, {String pattern = 'yyyy-MM-dd'}) {
  if (v == null) return '—';
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return '—';
    // If string already human-readable, just return it.
    // (If you want, you can try parse & reformat here.)
    return s;
  }
  if (v is Timestamp) return DateFormat(pattern).format(v.toDate());
  if (v is DateTime) return DateFormat(pattern).format(v);
  // Fallback
  return v.toString();
}

class ClusterDailyLogsDetailsScreen extends StatelessWidget {
  const ClusterDailyLogsDetailsScreen({
    super.key,
    required this.fiId,
    required this.docId,
  });

  final String fiId;   // <-- Field Incharge UID
  final String docId;  // <-- Log doc id

  DocumentReference<Map<String, dynamic>> _docRef() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(fiId)
        .collection('daily_logs')
        .doc(docId);
  }

  String _fmtDate(dynamic tsOrDate, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    if (tsOrDate == null) return '—';
    DateTime? dt;
    if (tsOrDate is Timestamp) {
      dt = tsOrDate.toDate();
    } else if (tsOrDate is DateTime) {
      dt = tsOrDate;
    }
    return dt == null ? '—' : DateFormat(pattern).format(dt);
    // ^ change pattern if you want (your FI screen shows “yyyy-MM-dd HH:mm”)
  }

  Widget _kv(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text((value ?? '—').toString()),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: const Text('Field Incharge - Daily Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/'); // fallback
            }
          },
        ),
        actions: [
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
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Log not found.'));
          }

          final m = snap.data!.data()!;
          // Common field names used in your FI screen – adjust keys if needed
          final dateOnly = _fmtDateFlexible(
            m['date'] ?? m['dateOnly'] ?? m['logDate'], // handle string or timestamp
            pattern: 'yyyy-MM-dd',
          );

          final createdAt = _fmtDateFlexible(
            m['createdAt'] ?? m['created_at'] ?? m['created'],
            pattern: 'yyyy-MM-dd HH:mm',
          );

          // Try the same keys your FI screen likely uses:
          final farmerField = _firstNonEmpty([
            m['farmerFieldId'],
            m['farmerId'],
            m['farmerField'],
            m['farmer'],
            m['fieldId'],
            m['field'],
            m['farmerCode'],
            m['farmerFieldCode'],
          ]);

          final activities = m['activities'];
          final plannedTime = m['plannedTime'] ?? m['planned_time'] ?? m['planned'];
          final actualTime = m['actualTime'] ?? m['actual_time'] ?? m['actual'];
          final remarks = m['remarks'];
          final inputs = m['inputs'];
          final issues = m['issues'];
          final nextAction = m['nextAction'] ?? m['next_action'];
          // Optional: title/filename if you store them
          final title = m['title'] ?? m['fileName'] ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if ((title ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(title.toString(),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              _kv('Date', dateOnly),
              _kv('Activities', activities),
              _kv('Farmer / Field', farmerField),
              _kv('Planned Time', plannedTime),
              _kv('Actual Time', actualTime),
              _kv('Remarks', remarks),
              _kv('Inputs', inputs),
              _kv('Issues', issues),
              _kv('Next Action', nextAction),
              _kv('Created At', createdAt),
            ],
          );
        },
      ),
    );
  }
}


String _firstNonEmpty(List values) {
  for (final v in values) {
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '—';
}
