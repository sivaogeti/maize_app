// lib/features/schedule/daily_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_clean/core/services/auth_service.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

String currentUid() => FirebaseAuth.instance.currentUser!.uid;

CollectionReference<Map<String, dynamic>> userLogsCol(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_logs');

class _SavedLogsTable extends StatelessWidget {
  const _SavedLogsTable();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: userLogsCol(uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Error loading logs: ${snap.error}'),
          );
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No saved logs yet for this user'),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Daily Log')),
            ],
            rows: docs.map<DataRow>((d) {
              final data = d.data();
              final ts = data['createdAt'];

              DateTime? dt;
              if (ts is Timestamp) {
                dt = ts.toDate();
              } else if (ts is String) {
                dt = DateTime.tryParse(ts);
              }

              final dateText =
              (dt != null) ? DateFormat('yyyy-MM-dd HH:mm').format(dt) : '—';

              return DataRow(cells: [
                DataCell(Text(dateText)),
                DataCell(
                  InkWell(
                    onTap: () => context.pushNamed(
                      'fi.daily.log.detail',
                      pathParameters: {'docId': d.id},
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Open',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

// -- helpers

CollectionReference<Map<String, dynamic>> _userLogsCol(String uid) =>
    FirebaseFirestore.instance
        .collection('users').doc(uid).collection('daily_logs');

const String kDailyLogsCollection = 'daily_logs';

const EdgeInsets _secPad = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

class LatLngLike {
  final double lat;
  final double lng;
  LatLngLike(this.lat, this.lng);
  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}


class ClusterDailyLogsScreen extends StatefulWidget {
  const ClusterDailyLogsScreen({super.key});

  @override
  State<ClusterDailyLogsScreen> createState() => _ClusterDailyLogsScreenState();
}

class _ClusterDailyLogsScreenState extends State<ClusterDailyLogsScreen> {

  // Form fields
  DateTime _date = DateTime.now();
  final _activitiesCtrl = TextEditingController();
  final _planTimeCtrl = TextEditingController();
  final _actualTimeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();


  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  // --- Inputs & Observations ---
  final _inputsCtrl = TextEditingController();
  final _issuesCtrl = TextEditingController();
  final _nextActionCtrl = TextEditingController();

// --- GPS tracking state ---
  StreamSubscription<Position>? _gpsSub;
  Position? _lastPos;
  double _distanceMeters = 0;
  final List<LatLngLike> _track = [];
  bool get _tracking => _gpsSub != null;

  bool _saving = false;            // gate: prevents double clicks

  late final String _uid;
  @override
  void initState() {
    super.initState();
    _loadFarmerIdItems();
    _uid = FirebaseAuth.instance.currentUser!.uid;
  }


  Future<void> _saveOnce() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final uid = _uid;
      await _userLogsCol(uid).add({
        // ── your existing fields ──
        'date': _ymd(_date),               // if you store a human date
        'activities': _activitiesCtrl.text,
        'farmerId': _farmerId,
        'plannedTime': _planTimeCtrl.text,
        'actualTime': _actualTimeCtrl.text,
        'remarks': _remarksCtrl.text,
        'inputs': _inputsCtrl.text,
        'issues': _issuesCtrl.text,
        'nextAction': _nextActionCtrl.text,
        // ── required for table sorting ──
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }



  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  // In your State class:
  List<DropdownMenuItem<String>> _farmerIdItems = [];

  // Farmer / Field list for the dropdown
  String? _farmerId; // whatever variable your dropdown already uses

  Future<void> _loadFarmerIdItems() async {
    setState(() {
    });

    try {
      // Ensure we have a logged-in user BEFORE querying
      final user = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance
              .authStateChanges()
              .firstWhere((u) => u != null);
      final uid = user!.uid;

      final db = FirebaseFirestore.instance;

      // Query both collections in parallel
      final results = await Future.wait([
        db
            .collection('farmers')
            .where('orgPathUids', arrayContains: uid)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get(),
        db
            .collection('farmer_registrations')
            .where('orgPathUids', arrayContains: uid)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get(),
      ]);

      final farmersSnap = results[0];
      final regsSnap    = results[1];

      final items = <DropdownMenuItem<String>>[
        ...farmersSnap.docs.map((d) => DropdownMenuItem(
          value: d.id,
          child: Text(d.id, overflow: TextOverflow.ellipsis),
        )),
        ...regsSnap.docs.map((d) => DropdownMenuItem(
          value: d.id,
          child: Text(d.id, overflow: TextOverflow.ellipsis),
        )),
      ];

      if (!mounted) return;
      setState(() {
        _farmerIdItems = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
      });
    }
  }


  Future<void> _toggleTracking() async {
    if (_tracking) {
      await _gpsSub?.cancel();
      setState(() => _gpsSub = null);
      return;
    }
    // Request permission & start stream
    final locEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      return; // user rejected
    }

    _distanceMeters = 0;
    _track.clear();
    _lastPos = null;

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // meters
    );

    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      if (_lastPos != null) {
        _distanceMeters += Geolocator.distanceBetween(
          _lastPos!.latitude, _lastPos!.longitude, pos.latitude, pos.longitude,
        );
      }
      _lastPos = pos;
      _track.add(LatLngLike(pos.latitude, pos.longitude));
      setState(() {});
    });
  }

  Future<List<String>> _orgPathUidsFor(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? const {};
    final List path = (data['orgPathUids'] ?? [uid]) as List;
    return path.map((e) => e.toString()).toList();
  }




  @override
  void dispose() {
    super.dispose();

    /*_activitiesCtrl.dispose();
    _planTimeCtrl.dispose();
    _actualTimeCtrl.dispose();
    _remarksCtrl.dispose();
    _inputsCtrl.dispose();
    _issuesCtrl.dispose();
    _nextActionCtrl.dispose();
    _gpsSub?.cancel();
    super.dispose();*/
  }

  @override
  Widget build(BuildContext context) {
    // If you later wire a FarmersProvider, replace this list with provider data.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logs & Schedule'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();                 // go_router back
              } else {
                context.push('/');               // or your home: '/dashboard'
              }
            }
        ),
        actions: [


          // 1) View
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'View saved',
            onPressed: () => context.pushNamed('fi.daily.logs.list'),
          ),



          // 2) Logout LAST
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date
          _Group(
            label: 'General',
            child: TextFormField(
              readOnly: true,
              controller: TextEditingController(text: _ymd(_date)),
              decoration: InputDecoration(
                labelText: 'Date',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  onPressed: _pickDate,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Activities
          _Group(
            label: 'Activities',
            child: TextFormField(
              controller: _activitiesCtrl,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Activities Performed',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Farmer / Field ID
          DropdownButtonFormField<String>(
            value: _farmerId,
            items: _farmerIdItems,
            onChanged: (v) => setState(() => _farmerId = v),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Farmer / Field ID',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Optional fields
          /*_Group(
            label: 'Times & Remarks (optional)',
            child: Column(
              children: [
                TextFormField(
                  controller: _planTimeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Planned Time',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _actualTimeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Actual Time',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
              ],
            ),
          ),*/
          Padding(
            padding: _secPad,
            child: TextField(
              controller: _nextActionCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Inputs & Observations',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: _secPad,
            child: TextField(
              controller: _inputsCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Inputs Supplied',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: _secPad,
            child: TextField(
              controller: _issuesCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Observations / Issues',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: _secPad,
            child: TextField(
              controller: _nextActionCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Next Action / Follow-up',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GPS Coverage (optional)',
                      style: Theme.of(context).textTheme.titleMedium),
                  FilledButton.tonalIcon(
                    onPressed: _toggleTracking,
                    icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
                    label: Text(_tracking ? 'Stop' : 'Start'),
                  ),
                ],
              )
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Distance covered: ${(_distanceMeters / 1000).toStringAsFixed(2)} km',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Text(
                'Map unavailable (tap Start to collect GPS)\n'
                    'You can later swap this with google_maps_flutter.',
                textAlign: TextAlign.center,
              ),
            ),
          ),


          const SizedBox(height: 24),
          // Full-width save button (optional – header icon also saves)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              /*onPressed: _saveToFirestore,
              icon: const Icon(Icons.save_outlined),*/
              onPressed: _saving ? null : _saveOnce,     // <— here
              icon: const Icon(Icons.save_alt),
              label: const Text('Save Log'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Saved Logs',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const _SavedLogsTable(),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
