import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerActivityScheduleScreen extends StatelessWidget {
  const ManagerActivityScheduleScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('activity_schedule').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Schedule')),
      body: SummaryCount(collectionLabel: 'Total Scheduled Activities', futureCount: _getCount()),
    );
  }
}
