import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerFieldDiagnosticsScreen extends StatelessWidget {
  const ManagerFieldDiagnosticsScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('field_diagnostics').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Diagnostics')),
      body: SummaryCount(collectionLabel: 'Total Diagnostics', futureCount: _getCount()),
    );
  }
}
