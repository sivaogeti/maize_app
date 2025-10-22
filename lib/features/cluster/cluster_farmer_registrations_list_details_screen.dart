import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';


class ClusterFarmerRegistrationsDetailsScreen extends StatefulWidget {
  final String uid;

  const ClusterFarmerRegistrationsDetailsScreen({
    Key? key,
    required this.uid,
  }) : super(key: key);

  @override
  State<ClusterFarmerRegistrationsDetailsScreen> createState() =>
      _ClusterFarmerRegistrationsDetailsScreenState();
}

class _ClusterFarmerRegistrationsDetailsScreenState extends State<ClusterFarmerRegistrationsDetailsScreen> {


  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final cicUid = auth.currentUserIdOrAnon;

    // FR docs live in "farmer_registrations"
    final q = FirebaseFirestore.instance
        .collection('farmer_registrations')
        .where('orgPathUids', arrayContains: cicUid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Incharge - Farmer Registrations Details Page'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // fall back to home (or CIC dashboard) if nothing to pop
              context.go('/');
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
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            },
          ),
        ],
      ),
      //appBar: AppBar(title: const Text('Farmers Registration Details')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _error('Error loading registrations: ${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No registrations found.'));

          return ListView.separated(


            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final d = docs[i].data();

              final doc = docs[i];
              final m = doc.data();
              final id    = (m['id']    as String?) ?? doc.id;
              final name  = (m['name']  as String?)?.trim();
              final phone = (m['phone'] as String?)?.trim();
              return ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: Text((name == null || name.isEmpty) ? id : name),
                subtitle: Text((phone ?? '').isEmpty ? '—' : phone!),
                trailing: const Text('Cluster', style: TextStyle(fontSize: 12)),
                onTap: () => _showRegistrationDetails(context, {
                  'id': id,
                  'name': name,
                  'phone': phone,
                  'residenceVillage': m['residenceVillage'],
                  'cropVillage':      m['cropVillage'],
                  'cluster':          m['cluster'],
                  'season':           m['season'],
                  'hybrid':           m['hybrid'],
                  'proposedArea':     m['proposedArea'],
                  'waterSource':      m['waterSource'],
                  'previousCrop':     m['previousCrop'],
                  'soilType':         m['soilType'],
                  'soilTexture':      m['soilTexture'],
                }),
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
}


void _showRegistrationDetails(BuildContext ctx, Map<String, dynamic> m) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      String v(Object? x) => (x ?? '').toString();

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Registration Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 8),
                const Divider(),

                _kv('ID',      v(m['id'])),
                _kv('Name',    v(m['name'])),
                _kv('Phone',   v(m['phone'])),
                const Divider(),
                _kv('Residence Village', v(m['residenceVillage'])),
                _kv('Crop Village',      v(m['cropVillage'])),
                _kv('Cluster',           v(m['cluster'])),
                const Divider(),
                _kv('Season',       v(m['season'])),
                _kv('Hybrid',       v(m['hybrid'])),
                _kv('Proposed Area',v(m['proposedArea'])),
                _kv('Water Source', v(m['waterSource'])),
                _kv('Previous Crop',v(m['previousCrop'])),
                _kv('Soil Type',    v(m['soilType'])),
                _kv('Soil Texture', v(m['soilTexture'])),
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

/// tiny key–value line (same style you used elsewhere)
Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 150, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v.isEmpty ? '—' : v)),
    ],
  ),
);
