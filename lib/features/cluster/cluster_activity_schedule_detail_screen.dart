// lib/features/cluster/cluster_activity_schedule_detail_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reusable farmer lookups. Use the SAME function on the FI screen too,
/// so both pages stay consistent.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FarmerRepo {
  static CollectionReference<Map<String, dynamic>> get _farmers =>
      FirebaseFirestore.instance.collection('farmers');

  static CollectionReference<Map<String, dynamic>> get _regs =>
      FirebaseFirestore.instance.collection('farmer_registrations');

  static Stream<List<String>> streamFarmerIdsForFi(String fiUid) {
    // wrap snapshots so permission errors don’t crash UI
    Stream<QuerySnapshot<Map<String, dynamic>>> safe(Query q, String tag) {
      final c = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      q.snapshots().listen(c.add as void Function(QuerySnapshot<Object?> event)?, onError: (e) {
        debugPrint('[CIC] $tag stream error (ignored): $e');
      });
      return c.stream;
    }

    // ---- farmer_registrations/ (most projects keep FRs here) ----
    final r1 = safe(_regs.where('fiUid', isEqualTo: fiUid), 'regs.fiUid');
    final r2 = safe(_regs.where('fieldInchargeUid', isEqualTo: fiUid), 'regs.fieldInchargeUid');
    final r3 = safe(_regs.where('fi_id', isEqualTo: fiUid), 'regs.fi_id');
    final r4 = safe(_regs.where('assignedFI', isEqualTo: fiUid), 'regs.assignedFI');
    final r5 = safe(_regs.where('ownerUid', isEqualTo: fiUid), 'regs.ownerUid');
    final r6 = safe(_regs.where('createdBy', isEqualTo: fiUid), 'regs.createdBy');

    // ---- farmers/ (some FN rows may live here) ----
    final f1 = safe(_farmers.where('fiUid', isEqualTo: fiUid), 'farmers.fiUid');
    final f2 = safe(_farmers.where('fieldInchargeUid', isEqualTo: fiUid), 'farmers.fieldInchargeUid');
    final f3 = safe(_farmers.where('fi_id', isEqualTo: fiUid), 'farmers.fi_id');
    final f4 = safe(_farmers.where('assignedFI', isEqualTo: fiUid), 'farmers.assignedFI');
    final f5 = safe(_farmers.where('ownerUid', isEqualTo: fiUid), 'farmers.ownerUid');
    final f6 = safe(_farmers.where('createdBy', isEqualTo: fiUid), 'farmers.createdBy');

    final streams = [r1,r2,r3,r4,r5,r6,f1,f2,f3,f4,f5,f6];
    final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(streams.length, null);
    final out = StreamController<List<String>>.broadcast();

    void emit() {
      final ids = <String>{};
      for (final snap in latest) {
        if (snap == null) continue;
        for (final d in snap.docs) {
          final m = d.data();
          // normalize an ID label
          final id = (m['farmerFieldId'] ?? m['farmerId'] ?? m['fieldId'] ?? m['id'] ?? d.id)
              .toString();
          if (id.isNotEmpty) ids.add(id);
        }
      }
      final list = ids.toList()..sort();
      out.add(list);
    }

    final subs = <StreamSubscription>[];
    for (var i = 0; i < streams.length; i++) {
      subs.add(streams[i].listen((snap) { latest[i] = snap; emit(); },
          onError: (e) => debugPrint('[CIC] union stream error: $e')));
    }
    out.onCancel = () { for (final s in subs) s.cancel(); };

    // Optional one-off debug counts (non-crashing)
    if (kDebugMode) {
      () async {
        Future<void> tryCount(CollectionReference<Map<String, dynamic>> col, String field) async {
          try {
            final n = (await col.where(field, isEqualTo: fiUid).limit(1).get()).size;
            debugPrint('[CIC] ${col.path} $field match = $n');
          } catch (e) {
            debugPrint('[CIC] ${col.path} $field count failed: $e');
          }
        }
        for (final field in ['fiUid','fieldInchargeUid','fi_id','assignedFI','ownerUid','createdBy']) {
          await tryCount(_regs, field);
          await tryCount(_farmers, field);
        }
      }();
    }

    return out.stream;
  }
}



const String kActivityScheduleCollection = 'activity_schedule';

// Paste EXACTLY the query from your FI page here.
Stream<List<String>> _farmerIdsSameAsFiPage(BuildContext context, String fiUid) {
  final q = FirebaseFirestore.instance
      .collection('<<<PASTE COLLECTION NAME>>>')     // ← paste
      .where('<<<PASTE FIELD NAME>>>', isEqualTo: fiUid); // ← paste

  return q.snapshots().map((snap) {
    final ids = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final id = (m['farmerFieldId'] ?? m['farmerId'] ?? m['fieldId'] ?? m['id'] ?? d.id).toString();
      if (id.isNotEmpty) ids.add(id);
    }
    final list = ids.toList()..sort();
    return list;
  });
}


/// Farmer/Field IDs under a specific FI (fallback to CIC if null).
Stream<List<String>> _farmerFieldIdsByFi(BuildContext context, {required String fiUid}) {
  // If your FI screen uses a different collection/field, paste the exact
  // collection+where from that screen here.
  final q = FirebaseFirestore.instance
      .collection('farmers')
      .where('fiUid', isEqualTo: fiUid); // or 'fieldInchargeUid'

  return q.snapshots().map((snap) {
    final ids = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final id = (m['id'] ?? m['farmerFieldId'] ?? m['farmerId'] ?? m['fieldId'] ?? d.id).toString();
      if (id.isNotEmpty) ids.add(id);
    }
    final list = ids.toList()..sort();
    return list;
  });
}


class _FiRef {
  final String uid;
  final String name;
  const _FiRef({required this.uid, required this.name});
}


Stream<List<_FiRef>> _fieldInchargesForCIC(BuildContext context) {
  final auth = context.read<AuthService>();
  final cicUid = auth.currentUser?.uid ?? auth.currentUserId ?? 'anon';

  final q = FirebaseFirestore.instance
      .collection('users') // adjust if different
      .where('orgPathUids', arrayContains: cicUid)
      .where('role', whereIn: ['field_incharge', 'FI']);

  return q.snapshots().map((snap) {
    final out = <_FiRef>[];
    for (final d in snap.docs) {
      final m = d.data();
      out.add(_FiRef(
        uid: d.id,
        name: (m['displayName'] ?? m['name'] ?? d.id).toString(),
      ));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  });
}

/// Returns all Farmer/Field IDs under a given FI by checking several
/// possible linkage fields + orgPathUids contains <fiUid>.
Stream<List<String>> _farmerFieldIdsForFiRobust(BuildContext context, String fiUid) {
  final base = FirebaseFirestore.instance.collection('farmers'); // <-- change if your collection name differs

  final s1 = base.where('fiUid', isEqualTo: fiUid).snapshots();
  final s2 = base.where('fieldInchargeUid', isEqualTo: fiUid).snapshots();
  final s3 = base.where('fi_id', isEqualTo: fiUid).snapshots();
  final s4 = base.where('assignedFI', isEqualTo: fiUid).snapshots();
  final s5 = base.where('ownerUid', isEqualTo: fiUid).snapshots();
  final s6 = base.where('orgPathUids', arrayContains: fiUid).snapshots();

  final controller = StreamController<List<String>>.broadcast();
  final subs = <StreamSubscription>[];
  final all = <String>{};

  void recalcAndEmit(Iterable<QuerySnapshot<Map<String, dynamic>>> snaps) {
    final set = <String>{};
    for (final snap in snaps) {
      for (final d in snap.docs) {
        final m = d.data();
        final id = (m['id'] ??
            m['farmerFieldId'] ??
            m['farmerId'] ??
            m['fieldId'] ??
            d.id)
            .toString();
        if (id.isNotEmpty) set.add(id);
      }
    }
    final list = set.toList()..sort();
    controller.add(list);
  }

  final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(6, null);

  void updateAndEmit(int i, QuerySnapshot<Map<String, dynamic>> snap) {
    latest[i] = snap;
    // emit only with non-null snaps; still safe to emit anytime
    recalcAndEmit(latest.whereType<QuerySnapshot<Map<String, dynamic>>>());
  }

  subs.add(s1.listen((snap) => updateAndEmit(0, snap)));
  subs.add(s2.listen((snap) => updateAndEmit(1, snap)));
  subs.add(s3.listen((snap) => updateAndEmit(2, snap)));
  subs.add(s4.listen((snap) => updateAndEmit(3, snap)));
  subs.add(s5.listen((snap) => updateAndEmit(4, snap)));
  subs.add(s6.listen((snap) => updateAndEmit(5, snap)));

  controller.onCancel = () {
    for (final s in subs) s.cancel();
  };

  // small debug to verify counts in your console
  // (remove once you see the correct numbers)
  // subs.add(s1.listen((s) => debugPrint('[CIC] fiUid count: ${s.size}')));
  // subs.add(s6.listen((s) => debugPrint('[CIC] orgPathUids count: ${s.size}')));

  return controller.stream;
}




class ClusterActivityScheduleDetailScreen extends StatelessWidget {
  const ClusterActivityScheduleDetailScreen({
    super.key,
    required this.docId,
  });

  final String docId;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(kActivityScheduleCollection);

  String _s(dynamic v) =>
      (v == null || v.toString().trim().isEmpty) ? '—' : v.toString();

  String _fmt(dynamic v, {String pattern = 'yyyy-MM-dd'}) {
    if (v == null) return '—';
    if (v is Timestamp) return DateFormat(pattern).format(v.toDate());
    if (v is DateTime)  return DateFormat(pattern).format(v);
    final t = v.toString().trim();
    return t.isEmpty ? '—' : t;
  }

  DataTable _opsTable(List list) => DataTable(
    columns: const [
      DataColumn(label: Text('S.No')),
      DataColumn(label: Text('Operation')),
      DataColumn(label: Text('Responsible')),
      DataColumn(label: Text('Recommended')),
      DataColumn(label: Text('Scheduled')),
      DataColumn(label: Text('Completed')),
      DataColumn(label: Text('Remarks')),
    ],
    rows: [
      for (final raw in list)
            () {
          final r = Map<String, dynamic>.from(raw as Map);

          return DataRow(cells: [
            DataCell(Text(_s(r['sno'] ?? r['SNo']))),
            DataCell(Text(_s(r['operation'] ?? r['name']))),
            DataCell(Text(_s(r['responsible'] ?? r['by']))),
            DataCell(Text(_s(r['recommendedTiming'] ?? r['recommended']))),
            DataCell(Text(_fmt(r['scheduled']))),
            DataCell(Text(_fmt(r['completed']))),
            DataCell(Text(_s(r['remarks']))),
          ]);
        }(),
    ],
    headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
    columnSpacing: 16,
    horizontalMargin: 12,
    showBottomBorder: true,
  );


  DataTable _actsTable(List list) => DataTable(
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
      for (final raw in list)
            () {
          final r = Map<String, dynamic>.from(raw as Map);

          return DataRow(cells: [
            DataCell(Text(_s(r['sno'] ?? r['SNo']))),
            DataCell(Text(_s(r['stageLabel'] ?? r['stage'] ?? r['cropStage']))),
            DataCell(Text(_s(r['activityWithSuppliers'] ?? r['activity'] ?? r['inputs']))),
            DataCell(Text(_s(r['supplier'] ?? r['by'] ?? r['responsible']))),
            DataCell(Text(_s(r['scheduled']))),
            DataCell(Text(_s(r['completed']))),
            DataCell(Text(_s(r['remarks']))),
          ]);
        }(),
    ],
    headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
    columnSpacing: 16,
    horizontalMargin: 12,
    showBottomBorder: true,
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity Schedule'),
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
          bottom: const TabBar(
            tabs: [Tab(text: 'Crop Operation'), Tab(text: 'Crop Protection')],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _col.doc(docId).snapshots(), // collection('activity_schedule').doc(docId)
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('Schedule not found'));
            }

            final m = snap.data!.data() as Map<String, dynamic>;

            final acts = (m['acts'] ?? m['activity'] ?? m['activities'] ?? const []) as List;
            final ops  = (m['ops']  ?? m['operations'] ?? const []) as List;

            // ⬇️ add these two lines here
            debugPrint('[CIC] acts len=${acts.length} '
                'keys=${acts.isNotEmpty ? (acts.first as Map).keys.toList() : 'EMPTY'}');
            debugPrint('[CIC] ops  len=${ops.length}  '
                'keys=${ops.isNotEmpty  ? (ops.first  as Map).keys.toList()  : 'EMPTY'}');

            String _s(dynamic v) =>
                (v == null || v.toString().trim().isEmpty) ? '—' : v.toString();

            final String farmerFieldId = _s(
              m['farmerOrFieldId'] ??
                  m['farmerFieldId'] ??
                  m['farmerId'] ??
                  m['fieldId'],
            );

            Stream<List<String>> _farmerFieldIdsForCIC(BuildContext context) {
              final auth = context.read<AuthService>();
              final cicUid = auth.currentUser?.uid ?? auth.currentUserId ?? 'anon';

              // Adjust collection name if yours differs (e.g. top-level "farmers")
              final q = FirebaseFirestore.instance
                  .collection('farmers')
                  .where('orgPathUids', arrayContains: cicUid);

              // Use the underlying broadcast snapshots stream and map it so multiple
              // StreamBuilders can listen without "Stream has already been listened to".
              return q.snapshots().map((snap) {
                final ids = <String>{};
                for (final d in snap.docs) {
                  final m = d.data();
                  final id = (m['id'] ?? m['farmerFieldId'] ?? m['farmerId'] ?? m['fieldId'] ?? d.id).toString();
                  if (id.isNotEmpty) ids.add(id);
                }
                final list = ids.toList()..sort();
                return list;
              });
            }

            /// navigate to the latest schedule for a chosen farmer/field
            Future<void> _openLatestFor(String farmerId) async {
              final auth = context.read<AuthService>();
              final cicUid = auth.currentUser?.uid ?? auth.currentUserId ?? 'anon';

              final col = FirebaseFirestore.instance.collection('activity_schedule');

              try {
                final shot = await col
                    .where('orgPathUids', arrayContains: cicUid)
                    .where('farmerOrFieldId', isEqualTo: farmerId)
                    .orderBy('dateYMD', descending: true)
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .get();

                if (shot.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No schedule for $farmerId')),
                  );
                  return;
                }
                context.goNamed(
                  'ci.activity.schedule.detail',
                  pathParameters: {'docId': shot.docs.first.id},
                );
              } on FirebaseException catch (e) {
                // fallback (no composite index yet): fetch a few and sort locally
                if (e.code == 'failed-precondition') {
                  final fb = await col
                      .where('orgPathUids', arrayContains: cicUid)
                      .where('farmerOrFieldId', isEqualTo: farmerId)
                      .limit(50)
                      .get();
                  if (fb.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No schedule for $farmerId')),
                    );
                    return;
                  }
                  final docs = [...fb.docs]..sort((a, b) {
                    final am = a.data(), bm = b.data();
                    final ay = (am['dateYMD'] ?? '').toString();
                    final by = (bm['dateYMD'] ?? '').toString();
                    final y = by.compareTo(ay);
                    if (y != 0) return y;
                    final ad = (am['createdAt'] is Timestamp)
                        ? (am['createdAt'] as Timestamp).toDate()
                        : DateTime.fromMillisecondsSinceEpoch(0);
                    final bd = (bm['createdAt'] is Timestamp)
                        ? (bm['createdAt'] as Timestamp).toDate()
                        : DateTime.fromMillisecondsSinceEpoch(0);
                    return bd.compareTo(ad);
                  });
                  context.goNamed(
                    'ci.activity.schedule.detail',
                    pathParameters: {'docId': docs.first.id},
                  );
                } else {
                  rethrow;
                }
              }
            }



            // header shown on both tabs
            // header shown on both tabs
            Widget header(String selectedId) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _CicHeaderChooser(
                  onPickFarmer: _openLatestFor,   // <— pass parent function here
                ),
              ),
            );




            String _fmt(dynamic v, {String pattern = 'yyyy-MM-dd'}) {
              if (v == null) return '—';
              if (v is Timestamp) return DateFormat(pattern).format(v.toDate());
              if (v is DateTime)  return DateFormat(pattern).format(v);
              final t = v.toString().trim();
              return t.isEmpty ? '—' : t;
            }

            String s(dynamic v) => (v == null || '$v'.trim().isEmpty) ? '—' : '$v';

            DataTable _actsTable(List list) => DataTable(
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
                for (final raw in list)
                      () {
                    final r = Map<String, dynamic>.from(raw as Map);

                    // helpers (keep your own _s/_fmt if you already have them)
                    String s(Object? v) => _s(v);
                    String d(Object? v) => _fmt(v);

                    return DataRow(cells: [
                      // 1) S.No
                      DataCell(Text(s(r['sno'] ?? r['SNo']))),

                      // 2) Crop Stage
                      DataCell(Text(s(r['stageLabel'] ?? r['stage'] ?? r['cropStage']))),

                      // 3) Activity / Inputs
                      DataCell(Text(s(r['activityWithSuppliers'] ?? r['activity'] ?? r['inputs']))),

                      // 4) Supplier
                      DataCell(Text(s(r['supplier'] ?? r['by'] ?? r['responsible']))),

                      // 5) Scheduled
                      DataCell(Text(d(r['scheduled']))),

                      // 6) Completed
                      DataCell(Text(d(r['completed']))),

                      // 7) Remarks
                      DataCell(Text(s(r['remarks']))),
                    ]);
                      }(),
              ],
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
              columnSpacing: 16,
              horizontalMargin: 12,
              showBottomBorder: true,
            );

            DataTable _opsTable(List list) => DataTable(
              columns: const [
                DataColumn(label: Text('S.No')),
                DataColumn(label: Text('Operation')),
                DataColumn(label: Text('Responsible')),
                DataColumn(label: Text('Recommended')),
                DataColumn(label: Text('Scheduled')),
                DataColumn(label: Text('Completed')),
                DataColumn(label: Text('Remarks')),
              ],
              rows: [
                for (final raw in list)
                      () {
                    final r = Map<String, dynamic>.from(raw as Map);

                    return DataRow(cells: [
                      DataCell(Text(s(r['sno'] ?? r['SNo'] ?? r['no']))),
                      DataCell(Text(s(r['operation'] ?? r['name'] ?? r['op']))),
                      DataCell(Text(s(r['responsible'] ?? r['resp'] ?? r['by']))),
                      DataCell(Text(s(r['recommendedTiming'] ?? r['recommended']))),
                      DataCell(Text(s(r['scheduled']))),
                      DataCell(Text(s(r['completed']))),
                      DataCell(Text(s(r['remarks']))),
                    ]);
                  }(),
              ],
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),
              columnSpacing: 16,
              horizontalMargin: 12,
              showBottomBorder: true,
            );


            final savedOn = _fmt(m['createdAt'], pattern: 'yyyy-MM-dd HH:mm');

            return TabBarView(
              children: [
                // Crop Operation
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    header(farmerFieldId),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _actsTable(acts),
                    ),
                    const SizedBox(height: 12),
                    Text('Saved on: $savedOn',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                // Crop Protection
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    header(farmerFieldId),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _opsTable(ops),
                    ),
                    const SizedBox(height: 12),
                    Text('Saved on: $savedOn',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _CicHeaderChooser extends StatefulWidget {
  const _CicHeaderChooser({
    required this.onPickFarmer,
  });

  final ValueChanged<String> onPickFarmer; // <— callback from parent

  @override
  State<_CicHeaderChooser> createState() => _CicHeaderChooserState();
}


class _CicHeaderChooserState extends State<_CicHeaderChooser> {

  Future<void> _debugFarmerCounts(String fiUid) async {
    final col = FirebaseFirestore.instance.collection('farmers'); // change if your collection differs

    for (final field in [
      'fiUid',
      'fieldInchargeUid',
      'fi_id',
      'assignedFI',
      'ownerUid'
    ]) {
      final n = (await col.where(field, isEqualTo: fiUid).limit(1).get()).size;
      debugPrint('[CIC] $field match = $n');
    }

    final nOrg = (await col
        .where('orgPathUids', arrayContains: fiUid)
        .limit(1)
        .get())
        .size;
    debugPrint('[CIC] orgPathUids contains = $nOrg');
  }


  String? _fiUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_FiRef>>(
      stream: _fieldInchargesForCIC(context),
      builder: (context, snap) {
        final fis = snap.data ?? const <_FiRef>[];

        // choose the FI to use now
        final String? effectiveFiUid =
            _fiUid ?? (fis.isNotEmpty ? fis.first.uid : null);

        // Debug: check which field in Firestore actually matches
        if (kDebugMode && effectiveFiUid != null) {
          _debugFarmerCounts(effectiveFiUid);
        }


        // ensure we pin _fiUid the first time data arrives, so subsequent
        // rebuilds keep the same value and farmer stream doesn't flicker.
        if (_fiUid == null && effectiveFiUid != null) {
          // schedule after build to avoid setState during build warning
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _fiUid = effectiveFiUid);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) Field Incharge dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: effectiveFiUid,
              decoration: const InputDecoration(
                labelText: 'Field Incharge',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final fi in fis)
                  DropdownMenuItem(value: fi.uid, child: Text(fi.name)),
              ],
              onChanged: (v) => setState(() {
                _fiUid = v;
                // when FI changes we want farmer list to refresh
                // _selectedFarmerFieldId = null; // if you keep selected farmer in state
              }),
            ),
            const SizedBox(height: 12),

            // 2) Farmer / Field ID dropdown
            if (effectiveFiUid == null)
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: null,
                decoration: const InputDecoration(
                  labelText: 'Farmer / Field ID',
                  border: OutlineInputBorder(),
                ),
                items: const [],
                onChanged: null, // disabled until FI list loads
              )
            else
              StreamBuilder<List<String>>(
                // ⬇️ use the effective UID right away, not _fiUid (which may still be null)
                stream: FarmerRepo.streamFarmerIdsForFi(effectiveFiUid),
                builder: (context, s) {
                  final ids = s.data ?? const <String>[];
                  final String? value = ids.isNotEmpty ? ids.first : null;

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: value,
                    decoration: const InputDecoration(
                      labelText: 'Farmer / Field ID',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final id in ids)
                        DropdownMenuItem(value: id, child: Text(id)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      // _openLatestFor(v);            // ❌ this is what errors
                      widget.onPickFarmer(v);          // ✅ call the callback
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
