// lib/features/cluster/farmer_network_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';

class FarmerNetworkDetailScreen extends StatelessWidget {
  final String docId;
  const FarmerNetworkDetailScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('farmers_network')   // <-- your collection
        .doc(docId);                      // <-- read single document

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agreement Details'),
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Not found'));
          }

          final m = snap.data!.data()!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Agreement Details',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),

              _kv('ID', m['id'] ?? docId),
              _kv('Name', m['name'] ?? ''),
              _kv('Phone', m['phone'] ?? ''),
              _kv('Residence Village', m['residenceVillage'] ?? ''),
              _kv('Crop Village', m['cropVillage'] ?? ''),
              _kv('Season', m['season'] ?? ''),
              _kv('Hybrid', m['hybrid'] ?? ''),
              _kv('Proposed Area', (m['proposedArea'] ?? '').toString()),
              _kv('Water Source', m['waterSource'] ?? ''),
              _kv('Previous Crop', m['previousCrop'] ?? ''),
              _kv('Soil Type', m['soilType'] ?? ''),
              _kv('Soil Texture', m['soilTexture'] ?? ''),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String key, String value) {
    final v = value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(key, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(v.isEmpty ? '—' : v)),
        ],
      ),
    );
  }


}
