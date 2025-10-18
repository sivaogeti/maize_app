import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

import 'dart:io';
import 'package:flutter/material.dart';

void _showAgreementDetailsFromMap(
    BuildContext context,
    Map<String, dynamic> m, {
      required String fallbackId,
    }) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AgreementDetailsSheet(m: m, fallbackId: fallbackId),
  );
}

class _AgreementDetailsSheet extends StatelessWidget {
  const _AgreementDetailsSheet({required this.m, required this.fallbackId});

  final Map<String, dynamic> m;
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    String _t(String key) => (m[key] as String? ?? '').trim();
    String id          = _t('id').isEmpty ? fallbackId : _t('id');
    String name        = _t('name');
    String phone       = _t('phone');
    String resVillage  = _t('residenceVillage');
    String cropVillage = _t('cropVillage');
    String cluster     = _t('cluster');
    String territory   = _t('territory');
    String season      = _t('season');
    String hybrid      = _t('hybrid');
    String proposed    = (m['proposedArea']?.toString() ?? '').trim();
    String water       = _t('waterSource');
    String previous    = _t('previousCrop');
    String soilType    = _t('soilType');
    String soilTexture = _t('soilTexture');

    // optional media
    final photoUrl  = m['photoUrl']  as String?; // if you saved a URL
    final photoPath = m['photoPath'] as String?; // if you saved a local path

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Farmer Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Divider(),

              _kv('ID', id),
              _kv('Name', name),
              _kv('Phone', phone),
              const Divider(),

              _kv('Residence Village', resVillage),
              _kv('Crop Village', cropVillage),
              _kv('Cluster', cluster.isEmpty ? '—' : cluster),
              _kv('Territory', territory.isEmpty ? '—' : territory),
              const Divider(),

              _kv('Season', season),
              _kv('Hybrid', hybrid),
              _kv('Proposed Area', proposed),
              _kv('Water Source', water),
              _kv('Previous Crop', previous),
              _kv('Soil Type', soilType),
              _kv('Soil Texture', soilTexture),
              const SizedBox(height: 12),

              if ((photoUrl ?? '').isNotEmpty) ...[
                Text('Photo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(photoUrl!, height: 140, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
              ] else if ((photoPath ?? '').isNotEmpty && File(photoPath!).existsSync()) ...[
                Text('Photo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(photoPath!), height: 140, fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v.isEmpty ? '—' : v)),
        ],
      ),
    );
  }
}

class ClusterFarmersNetworkListScreen extends StatelessWidget {
  const ClusterFarmersNetworkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final cicUid = auth.currentUserIdOrAnon;

    // FN docs live in "farmers" per your current data model; we filter by orgPathUids
    final q = FirebaseFirestore.instance
        .collection('farmers')
        .where('orgPathUids', arrayContains: cicUid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmers Network Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/'); // fallback
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthService>().logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _error('Error loading networks: ${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No farmer networks found.'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final title = (d['name'] ?? d['id'] ?? '') as String;
              final sub   = [
                if ((d['cropVillage'] ?? '').toString().isNotEmpty) d['cropVillage'],
                if ((d['territory'] ?? '').toString().isNotEmpty) d['territory'],
                if ((d['cluster'] ?? '').toString().isNotEmpty) d['cluster'],
              ].where((e) => (e ?? '').toString().isNotEmpty).join(' • ');

              final doc   = docs[i];
              final m     = doc.data();
              final docId = m['id'] as String? ?? doc.id;

              return ListTile(
                title: Text(title),
                subtitle: sub.isEmpty ? null : Text(sub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAgreementDetailsFromMap(context, m, fallbackId: docId), // ✅
              );
            },

          );
        },
      ),
    );
  }

  Widget _error(String m) => Padding(
    padding: const EdgeInsets.all(16),
    child: SelectableText(m, style: const TextStyle(color: Colors.red)),
  );

  // Bottom-sheet details (same style you used for FI details)
  void _showAgreementDetails(BuildContext ctx, Map<String, dynamic> m, {required String fallbackId}) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(k, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              Expanded(child: Text(v.isEmpty ? '—' : v)),
            ],
          ),
        );

        String s(String key) => (m[key] as String?)?.trim() ?? '';

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Agreement Details',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Divider(),

                  kv('ID', s('id').isEmpty ? fallbackId : s('id')),
                  kv('Name', s('name')),
                  kv('Phone', s('phone')),
                  const Divider(),

                  kv('Residence Village', s('residenceVillage')),
                  kv('Crop Village', s('cropVillage')),
                  kv('Cluster', s('cluster')),
                  const Divider(),

                  kv('Season', s('season')),
                  kv('Hybrid', s('hybrid')),
                  kv('Proposed Area', s('proposedArea')),
                  kv('Water Source', s('waterSource')),
                  kv('Previous Crop', s('previousCrop')),
                  kv('Soil Type', s('soilType')),
                  kv('Soil Texture', s('soilTexture')),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


}


