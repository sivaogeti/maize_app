import 'package:flutter/material.dart';
import '../../core/models/farmer.dart';

class FarmerDetailsSheet extends StatelessWidget {
  final Farmer farmer;
  const FarmerDetailsSheet({super.key, required this.farmer});

  Widget _kv(String k, String? v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text((v == null || v.isEmpty) ? '—' : v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = farmer;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Farmer Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _kv('ID', f.id),
              _kv('Name', f.name),
              _kv('Phone', f.phone),
              const Divider(),
              _kv('Residence Village', f.residenceVillage),
              _kv('Crop Village', f.cropVillage),
              _kv('Cluster', f.cluster),
              _kv('Territory', f.territory),
              const Divider(),
              _kv('Season', f.season),
              _kv('Hybrid', f.hybrid),
              _kv('Proposed Area', f.plantedArea?.toString()),
              _kv('Water Source', f.waterSource),
              _kv('Previous Crop', f.previousCrop),
              _kv('Soil Type', f.soilType),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
