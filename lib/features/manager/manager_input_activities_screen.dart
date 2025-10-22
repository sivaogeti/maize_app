import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerInputActivityScreen extends StatelessWidget {
  const ManagerInputActivityScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('input_supplies').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Activity')),
      body: SummaryCount(collectionLabel: 'Total Input Records', futureCount: _getCount()),
    );
  }
}
