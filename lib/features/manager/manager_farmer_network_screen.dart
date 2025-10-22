import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/summary_count.dart';

class ManagerFarmerNetworkScreen extends StatelessWidget {
  const ManagerFarmerNetworkScreen({super.key});

  Future<int> _getCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('farmers_network').get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Network')),
      body: SummaryCount(collectionLabel: 'Total Farmers', futureCount: _getCount()),
    );
  }
}
