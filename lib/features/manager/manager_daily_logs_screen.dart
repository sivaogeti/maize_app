import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerFieldInchargeDailyLogsScreen extends StatelessWidget {
  const ManagerFieldInchargeDailyLogsScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('daily_logs').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Incharge Daily Logs')),
      body: SummaryCount(collectionLabel: 'Total Logs', futureCount: _getCount()),
    );
  }
}
