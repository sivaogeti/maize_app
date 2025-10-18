import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/field_observations_provider.dart';

class FieldObservationsListScreen extends StatelessWidget {
  const FieldObservationsListScreen({super.key});

  String _fmtDate(dynamic v) {
    if (v is Timestamp) return DateFormat('yyyy-MM-dd').format(v.toDate());
    if (v is DateTime) return DateFormat('yyyy-MM-dd').format(v);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FieldObservationsProvider>();
    final items = p.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Observations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FieldObservationsProvider>().bind(),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No observations yet'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final d = items[i].data;
          final date = _fmtDate(d['date']);
          final farmer = (d['farmerOrFieldId'] ?? '') as String;
          final stage = (d['cropStage'] ?? '') as String;
          final cats = (d['categories'] ?? []) as List;
          final catsText = cats.join(', ');

          return ListTile(
            leading: const Icon(Icons.note_alt_outlined),
            title: Text('$farmer • $date'),
            subtitle: Text([stage, catsText].where((e) => e.isNotEmpty).join(' • ')),
            onTap: () {
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (ctx) => _ObservationDetails(data: d),
              );
            },
          );
        },
      ),
    );
  }
}

class _ObservationDetails extends StatelessWidget {
  const _ObservationDetails({required this.data});
  final Map<String, dynamic> data;

  String _fmt(dynamic v) {
    if (v == null) return '';
    if (v is Timestamp) return DateFormat('yyyy-MM-dd').format(v.toDate());
    if (v is DateTime) return DateFormat('yyyy-MM-dd').format(v);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cats = (data['categories'] ?? []) as List;
    final kv = (String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            kv('Date', _fmt(data['date'])),
            kv('Farmer / Field ID', (data['farmerOrFieldId'] ?? '').toString()),
            kv('Crop & Stage', (data['cropStage'] ?? '').toString()),
            kv('Categories', cats.join(', ')),
            if ((data['notes'] ?? '').toString().isNotEmpty)
              kv('Notes', data['notes'].toString()),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
