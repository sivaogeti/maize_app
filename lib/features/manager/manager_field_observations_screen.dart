import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerFieldObservationsScreen extends StatelessWidget {
  const ManagerFieldObservationsScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('field_observations').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Observations')),
      body: SummaryCount(collectionLabel: 'Total Observations', futureCount: _getCount()),
    );
  }
}
