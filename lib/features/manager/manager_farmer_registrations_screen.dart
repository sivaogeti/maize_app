import 'package:app_clean/features/manager/widgets/summary_count.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerFarmerRegistrationsScreen extends StatelessWidget {
  const ManagerFarmerRegistrationsScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('farmer_registrations').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Registrations')),
      body: SummaryCount(collectionLabel: 'Total Registrations', futureCount: _getCount()),
    );
  }
}
