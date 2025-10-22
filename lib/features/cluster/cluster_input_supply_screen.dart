import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClusterInputSupplyListScreen extends StatefulWidget {
  const ClusterInputSupplyListScreen({super.key});

  @override
  State<ClusterInputSupplyListScreen> createState() =>
      _ClusterInputSupplyListScreenState();
}

class _ClusterInputSupplyListScreenState extends State<ClusterInputSupplyListScreen> {
  String? _selectedFiId;

  @override
  Widget build(BuildContext context) {
    final meUid = FirebaseAuth.instance.currentUser!.uid;

    final fiQuery = FirebaseFirestore.instance
        .collection('users')
        .where('orgPathUids', arrayContains: meUid);




    return Scaffold(
      appBar: AppBar(title: const Text('Field Incharge Inputs Details')),
      body: StreamBuilder<QuerySnapshot>(
        stream: fiQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs
              .where((d) => ((d.data() as Map<String, dynamic>)['roles'] as List?)?.contains('field_incharge') ?? false)
              .toList();


          return Column(
            children: [
              DropdownButton<String>(
                value: _selectedFiId,
                hint: const Text('Select Field Incharge'),
                items: docs.map((d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(d['name'] ?? 'No name'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedFiId = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectedFiId == null
                    ? null
                    : () {
                  context.pushNamed(
                    'ci.field_incharges.inputs-details.detail',
                    pathParameters: {'uid': _selectedFiId!},
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }
}