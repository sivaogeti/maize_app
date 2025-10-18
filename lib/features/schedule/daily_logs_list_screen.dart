import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

CollectionReference<Map<String, dynamic>> _userLogsCol(String uid) =>
    FirebaseFirestore.instance
        .collection('users').doc(uid).collection('daily_logs');

class DailyLogsListScreen extends StatelessWidget {
  const DailyLogsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;



    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          // 1) Log Out
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _userLogsCol(uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No saved logs yet'));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Daily Log')),
              ],
              rows: docs.map((d) {
                final data = d.data();
                final ts = data['createdAt'];

                DateTime? dt;
                if (ts is Timestamp) {
                  dt = ts.toDate();
                } else if (ts is String) {
                  dt = DateTime.tryParse(ts);
                }

                final dateText =
                dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : '—';
                final linkText =
                dt != null ? 'Dailylogs-${DateFormat('dMMMyyyy').format(dt)}' : 'Open';

                return DataRow(cells: [
                  DataCell(Text(dateText)),
                  DataCell(
                    InkWell(
                      onTap: () => context.pushNamed(
                        'fi.daily.log.detail',
                        pathParameters: {'docId': d.id},
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          linkText,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
