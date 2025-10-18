// lib/features/farmers/farmers_screen.dart
import 'package:flutter/material.dart';

// Use the repository + the real model from data/models
import 'package:app_clean/data/repositories/farmer_repository.dart';
import 'package:app_clean/data/models/farmer.dart' as m;

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final farmersRepo = FarmerRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmers (Local)')),
      body: StreamBuilder<List<m.FarmerLocal>>(
        stream: farmersRepo.watchLocal(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <m.FarmerLocal>[];
          if (items.isEmpty) {
            return const Center(child: Text('No local farmers yet'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final f = items[index];
              final updated = f.updatedAt ?? DateTime.now();
              return ListTile(
                title: Text(f.name ?? '(no name)'),
                subtitle: Text('${f.phone ?? ''}  •  updated $updated'),
                trailing: (f.pending ?? false)
                    ? const Icon(Icons.cloud_upload)
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final now = DateTime.now();
          final f = m.FarmerLocal()
            ..farmerId = ''
            ..orgId = 'ORG1'
            ..name = 'Farmer ${now.millisecondsSinceEpoch % 1000}'
            ..phone = '9XXXXXXXXX'
            ..updatedAt = now
            ..deleted = false;
          await farmersRepo.upsertLocal(f, pending: true);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add local'),
      ),
    );
  }
}
