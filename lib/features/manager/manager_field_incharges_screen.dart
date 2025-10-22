import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerFieldInchargeDetailsScreen extends StatelessWidget {
  const ManagerFieldInchargeDetailsScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('field_incharges').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Incharge Details')),
      body: SummaryCount(collectionLabel: 'Total Field Incharges', futureCount: _getCount()),
    );
  }
}
