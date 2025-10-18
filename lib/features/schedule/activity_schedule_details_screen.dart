import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kActivityScheduleCollection = 'activity_schedule';

// Minimal fallback rows (replace with your full template if available)
const List<Map<String, String>> kActivityTemplate = [
  {'stage': 'Before sowing',  'activity': '1.5 Bag DAP + 0.5 kg Zinc Sulphate OR 3 Bags SSP', 'supplier': 'Farmer'},
  {'stage': '1–2 days',       'activity': 'Atrazine 0.5 kg or Atrazine 1 kg',                  'supplier': 'Company'},
  {'stage': '12–14 days',     'activity': 'Spolit / Proclaim (Emamectin Benzoate) 100 g',      'supplier': 'Company'},
  {'stage': '15 days',        'activity': 'Neem Urea 0.5 l + Neem oil 200:15',                 'supplier': 'Farmer'},
  {'stage': '18–20 days',     'activity': 'Gunther 500 ml + Chelamin Zinc 100 gm',             'supplier': 'Company'},
];

String _str(dynamic v) {
  if (v == null) return '—';
  final s = v.toString().trim();
  return s.isEmpty ? '—' : s;
}

String _fmtDate(dynamic v, {String pattern = 'yyyy-MM-dd'}) {
  if (v == null) return '—';
  if (v is Timestamp) return DateFormat(pattern).format(v.toDate());
  if (v is DateTime)  return DateFormat(pattern).format(v);
  final s = v.toString().trim();
  return s.isEmpty ? '—' : s;
}

String _tplStage(int i) => i < kActivityTemplate.length ? (kActivityTemplate[i]['stage'] ?? '—') : '—';
String _tplAct(int i)   => i < kActivityTemplate.length ? (kActivityTemplate[i]['activity'] ?? '—') : '—';
String _tplSup(int i)   => i < kActivityTemplate.length ? (kActivityTemplate[i]['supplier'] ?? '—') : '—';

String _dateSuffixFromDocId(String docId) {
  final idx = docId.lastIndexOf('_');
  if (idx <= 0 || idx + 1 >= docId.length) return DateFormat('yyyy-MM-dd').format(DateTime.now());
  final suffix = docId.substring(idx + 1);
  final ok = RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(suffix);
  return ok ? suffix : DateFormat('yyyy-MM-dd').format(DateTime.now());
}

class ActivityScheduleDetailsScreen extends StatefulWidget {
  const ActivityScheduleDetailsScreen({super.key, required this.docId});
  final String docId;

  @override
  State<ActivityScheduleDetailsScreen> createState() => _ActivityScheduleDetailsScreenState();
}

class _ActivityScheduleDetailsScreenState extends State<ActivityScheduleDetailsScreen> {
  late String _docId;

  @override
  void initState() {
    super.initState();
    _docId = widget.docId;
  }

  void smartBack(BuildContext context) {
    // 1) Close dialogs/sheets shown with rootNavigator: true
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop();
      return;
    }

    // 2) Pop GoRouter stack if possible
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    // Nothing to pop → go to the list page
    router.goNamed('fi.activity.schedule.list'); // <-- not '/activity'
  }


  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection(kActivityScheduleCollection);
    final currentDateSuffix = _dateSuffixFromDocId(_docId);

    // Dropdown of IDs from farmers + registrations filtered by current user
    Widget idDropdown(String currentId) => FutureBuilder<List<String>>(
      future: () async {
        final ids = <String>{};

        final user = FirebaseAuth.instance.currentUser ??
            await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null);
        final uid = user!.uid;

        final db = FirebaseFirestore.instance;
        try {
          final results = await Future.wait([
            db.collection('farmers').where('orgPathUids', arrayContains: uid).limit(500).get(),
            db.collection('farmer_registrations').where('orgPathUids', arrayContains: uid).limit(500).get(),
          ]);
          for (final d in results[0].docs) ids.add(d.id.trim());
          for (final d in results[1].docs) ids.add(d.id.trim());
        } catch (_) {}

        try {
          final sch = await col.doc(_docId).get();
          final m = sch.data();
          if (m != null) {
            final cand = [m['farmerOrFieldId'], m['farmerFieldId'], m['farmerId'], m['fieldId']];
            for (final v in cand) {
              final s = v?.toString().trim();
              if (s != null && s.isNotEmpty) ids.add(s);
            }
          }
        } catch (_) {}

        final list = ids.toList()..sort();
        return list;
      }(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(height: 40, child: LinearProgressIndicator()),
          );
        }
        final list = snap.data ?? const <String>[];
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No Farmer / Field IDs found'),
          );
        }
        final currentPrefix = _docId.contains('_') ? _docId.split('_').first : '';
        final value = list.contains(currentPrefix)
            ? currentPrefix
            : (currentId.isNotEmpty && list.contains(currentId) ? currentId : list.first);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Farmer / Field ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [for (final s in list) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (val) {
              if (val == null) return;
              final newDocId = '${val.trim()}_${currentDateSuffix}';
              setState(() {
                _docId = newDocId; // re-stream without navigating
              });
            },
          ),
        );
      },
    );

    return PopScope(
        canPop: false, // we’ll decide what “back” should do
        onPopInvoked: (didPop) {
          if (!didPop) smartBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Activity Schedule Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => smartBack(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () {
                  try {
                    context.read<AuthService>().logout();
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: col.doc(_docId).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Schedule not found'));
          }

          final data = snap.data!.data()!;
          final acts = (data['activities'] as List?) ?? const [];
          final ops  = (data['operations'] as List?) ?? const [];
          final farmerFieldId = _str(data['farmerOrFieldId'] ?? data['farmerFieldId'] ?? data['farmerId'] ?? data['fieldId']);

          final totalRows = (acts.length > kActivityTemplate.length) ? acts.length : kActivityTemplate.length;

          DataTable actsTable() => DataTable(
            columns: const [
              DataColumn(label: Text('S.No')),
              DataColumn(label: Text('Crop Stage')),
              DataColumn(label: Text('Activity / Inputs')),
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Scheduled')),
              DataColumn(label: Text('Completed')),
              DataColumn(label: Text('Remarks')),
            ],
            rows: [
              for (int i = 0; i < totalRows; i++)
                    () {
                  final row = (i < acts.length) ? (acts[i] as Map).cast<String, dynamic>() : <String, dynamic>{};
                  final sno   = row['sno'] ?? (i + 1);
                  final stage = _str(row['cropStage'] ?? row['stageLabel'] ?? row['stage']);
                  final act   = _str(row['activity']   ?? row['activityWithSuppliers'] ?? row['inputs']);
                  final sup   = _str(row['supplier']   ?? row['responsible'] ?? row['by']);
                  final sch   = _fmtDate(row['scheduled']);
                  final cmp   = _fmtDate(row['completed']);
                  final rem   = _str(row['remarks']);
                  return DataRow(cells: [
                    DataCell(Text('$sno')),
                    DataCell(Text(stage == '—' ? _tplStage(i) : stage)),
                    DataCell(Text(act   == '—' ? _tplAct(i)   : act)),
                    DataCell(Text(sup   == '—' ? _tplSup(i)   : sup)),
                    DataCell(Text(sch)),
                    DataCell(Text(cmp)),
                    DataCell(Text(rem)),
                  ]);
                }(),
            ],
          );

          DataTable opsTable() => DataTable(
            columns: const [
              DataColumn(label: Text('S.No')),
              DataColumn(label: Text('Operation')),
              DataColumn(label: Text('Scheduled')),
              DataColumn(label: Text('Responsible')),
              DataColumn(label: Text('Recommended')),
              DataColumn(label: Text('Completed')),
              DataColumn(label: Text('Remarks')),
            ],
            rows: [
              for (int i = 0; i < ops.length; i++)
                    () {
                  final row = (ops[i] as Map).cast<String, dynamic>();
                  return DataRow(cells: [
                    DataCell(Text(_str(row['sno'] ?? row['SNo']))),
                    DataCell(Text(_str(row['operation'] ?? row['name']))),
                    DataCell(Text(_fmtDate(row['scheduled']))),
                    DataCell(Text(_str(row['responsible'] ?? row['by']))),
                    DataCell(Text(_str(row['recommendedTiming'] ?? row['recommended']))),
                    DataCell(Text(_fmtDate(row['completed']))),
                    DataCell(Text(_str(row['remarks']))),
                  ]);
                }(),
            ],
          );

          return DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                idDropdown(farmerFieldId == '—' ? '' : farmerFieldId),
                const TabBar(tabs: [
                  Tab(text: 'Crop Operation'),
                  Tab(text: 'Crop Protection'),
                ]),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actsTable(),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: opsTable(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
     ),
    );
  }
}
