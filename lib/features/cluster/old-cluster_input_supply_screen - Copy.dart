import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

import 'package:intl/intl.dart';

class ClusterInputSupplyListScreen extends StatefulWidget {
  final String? uid;

  const ClusterInputSupplyListScreen({Key? key, this.uid}) : super(key: key);

  @override
  State<ClusterInputSupplyListScreen> createState() =>
      _ClusterInputSupplyListScreenScreenState();
}

class _ClusterInputSupplyListScreenScreenState extends State<ClusterInputSupplyListScreen>  {
  String? _selectedFiId;          // chosen Field Incharge uid (from dropdown)
  bool _submitted = false;        // after clicking Submit, we lock to one FI
  String? _selectedLogId;         // chosen log doc id (from logs dropdown)


  // ---- Firestore helpers ---------------------------------------------------

  /// All FIs that report to this CI
  Query<Map<String, dynamic>> _fiQuery(String ciUid) => FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'field_incharge')
      .where('clusterInchargeUid', isEqualTo: ciUid); // <-- use your field

  /// FI's daily logs collection
  CollectionReference<Map<String, dynamic>> _logsCol(String fiUid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(fiUid)
          .collection('daily_logs');

  /// A single log doc
  DocumentReference<Map<String, dynamic>> _logDoc(String fiUid, String docId) =>
      _logsCol(fiUid).doc(docId);


  @override
  Widget build(BuildContext context) {

    final ciUid = FirebaseAuth.instance.currentUser!.uid;

    // query: users with role field_incharge and in same org path
    final auth  = context.read<AuthService>();
    final cicUid = auth.currentUser!.uid; // or your helper

    // List<String>
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'field_incharge')
        .where('orgPathUids', arrayContains: cicUid)
        .orderBy('displayName');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Incharge - Input Details List Page'),
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
              await context.read<AuthService>().signOut();
              if (!context.mounted) return;
              // GoRouter:
              context.go('/login');
              // (If you use Navigator 1.0 instead)
              // Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) Field Incharge dropdown + Submit
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _fiQuery(ciUid).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 64, child: Center(child: CircularProgressIndicator()));
                  }
                  final docs = snap.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return const Text('No Field Incharges mapped to you.');
                  }

                  // If nothing selected yet, default to first item (until submitted)
                  _selectedFiId ??= !_submitted ? docs.first.id : _selectedFiId;


                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedFiId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Field Incharge',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final d in docs)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text(d.data()['displayName'] ?? d.id), // <-- use displayName
                            ),
                        ],
                        onChanged: _submitted
                            ? null
                            : (v) => setState(() {
                          _selectedFiId = v;
                          _selectedLogId = null; // reset log selection
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
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
                          const SizedBox(width: 12),
                          if (_submitted)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _submitted = false;
                                _selectedLogId = null;
                              }),
                              icon: const Icon(Icons.edit),
                              label: const Text('Change FI'),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2) Logs list (table style) with headers, like FI screen
          if (_submitted && _selectedFiId != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _logsCol(_selectedFiId!)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                          height: 64, child: Center(child: CircularProgressIndicator()));
                    }
                    final logs = snap.data?.docs ?? const [];
                    if (logs.isEmpty) return const Text('No daily logs for this FI.');

                    // if nothing selected yet, pick the first
                    _selectedLogId ??= logs.first.id;

                    String dateOf(Map<String, dynamic> m) {
                      final ts = m['createdAt'] as Timestamp?;
                      final dt = ts?.toDate();
                      return dt == null ? '—' : DateFormat('yyyy-MM-dd HH:mm').format(dt);
                    }

                    /// Produce the same human label the FI screen shows.
                    /// Priority: title > fileName > name > first words of activities > fallback(docId)
                    String humanTitle(Map<String, dynamic> m, String docId) {
                      String pick(String key) {
                        final v = (m[key] ?? '').toString().trim();
                        return v.isEmpty ? '' : v;
                      }

                      final t1 = pick('title');
                      if (t1.isNotEmpty) return t1;

                      final t2 = pick('fileName'); // often "Dailylogs-10Oct2025"
                      if (t2.isNotEmpty) return t2;

                      final t3 = pick('name');
                      if (t3.isNotEmpty) return t3;

                      final acts = pick('activities');
                      if (acts.isNotEmpty) {
                        // take the first line / first 40 chars so it looks like a name
                        final firstLine = acts.split('\n').first.trim();
                        return firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine;
                      }

                      return docId; // last resort
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Logs', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),

                        // ---- Header row (Date | Daily Log)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 140, // keep same width for alignment
                                child: Text('Date',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                child: Text('Daily Log',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 16),

                        // ---- Rows
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final doc = logs[i];
                            final m = doc.data();
                            final dateStr = dateOf(m);
                            final title = humanTitle(m, doc.id);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(width: 140, child: Text(dateStr)),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => context.pushNamed(
                                        'ci.daily.log.detail',
                                        pathParameters: {
                                          'fiId': _selectedFiId!,   // selected Field Incharge
                                          'docId': doc.id,          // selected log document ID
                                        },
                                      ),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text('Total logs: ${logs.length}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    );
                  },
                ),
              ),
            ),


          // 3) Selected log details (visible after a log is chosen)
          if (_submitted && _selectedFiId != null && _selectedLogId != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _logDoc(_selectedFiId!, _selectedLogId!).snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                          height: 120, child: Center(child: CircularProgressIndicator()));
                    }
                    if (!snap.hasData || !snap.data!.exists) {
                      return const Text('Log not found.');
                    }
                    final d = snap.data!.data()!;
                    final ts = d['createdAt'] as Timestamp?;
                    final dt = ts?.toDate();
                    final dateStr =
                    dt != null ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : '—';

                    Widget kv(String k, Object? v) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text((v ?? '—').toString()),
                        ],
                      ),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Log Details',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        kv('Date/Time', dateStr),
                        kv('Title', d['title']),
                        kv('Activities', d['activities']),
                        kv('Notes', d['notes']),
                        // add more fields as your schema requires
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

}