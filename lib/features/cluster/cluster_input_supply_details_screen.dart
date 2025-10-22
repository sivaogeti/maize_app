// lib/features/inputs/inputs_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class ClusterInputSupplyDetailsScreen extends StatelessWidget {
  final String uid;

  const ClusterInputSupplyDetailsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final meUid = FirebaseAuth.instance.currentUser!.uid;

    final query = FirebaseFirestore.instance
        .collection('input_supplies')
        .where('createdBy', isEqualTo: uid)
        .where('orgPathUids', arrayContains: meUid);

    return Scaffold(
      appBar: AppBar(title: const Text('Input Supply Details')),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text('No input details found'));

          return ListView(
            children: docs
                .map((doc) => ListTile(
              title: Text(doc['inputName'] ?? 'No name'),
              subtitle: Text('Qty: ${doc['quantity'] ?? 'N/A'}'),
            ))
                .toList(),
          );
        },
      ),
    );
  }
}

