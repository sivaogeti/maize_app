import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:app_clean/core/services/auth_service.dart';
import 'package:app_clean/core/services/field_diagnostics_provider.dart';

import '../../core/services/audit_meta.dart';

class FieldDiagnosticsScreen extends StatefulWidget {
  const FieldDiagnosticsScreen({super.key});

  @override
  State<FieldDiagnosticsScreen> createState() => _FieldDiagnosticsScreenState();
}

class _FieldDiagnosticsScreenState extends State<FieldDiagnosticsScreen> {
  // Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Form state
  DateTime _date = DateTime.now();
  final TextEditingController _cropStageCtrl = TextEditingController();
  final TextEditingController _issuesCtrl = TextEditingController();
  final TextEditingController _recommendCtrl = TextEditingController();

  // Farmer / Field IDs loaded from Firestore (farmers collection)
  List<String> _farmerIds = <String>[];
  String? _selectedFarmerId;

  // Layout helpers
  static const EdgeInsets _secPad =
  EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets _pagePad =
  EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  @override
  void initState() {
    super.initState();
    _fetchFarmerIds();
    _loadFarmerIdItems();
  }

  @override
  void dispose() {
    _cropStageCtrl.dispose();
    _issuesCtrl.dispose();
    _recommendCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFarmerIds() async {
    try {
      final snap = await _db.collection('farmers').get();
      final set = <String>{};
      for (final d in snap.docs) {
        // Prefer the "id" field if present; otherwise use the document id.
        final data = d.data();
        final id = (data['id'] ?? d.id).toString().trim();
        if (id.isNotEmpty) set.add(id);
      }
      final list = set.toList()..sort();
      if (mounted) {
        setState(() => _farmerIds = list);
      }
    } catch (_) {
      // If fetching farmers fails, we simply keep an empty list.
    }
  }

  // In your State class:
  bool _farmerIdLoading = false;
  List<DropdownMenuItem<String>> _farmerIdItems = [];
  String? _farmerIdError; // optional
  // Farmer / Field list for the dropdown
  String? _farmerId; // whatever variable your dropdown already uses
  bool _loadingFarmers = false;

  Future<void> _loadFarmerIdItems() async {
    setState(() {
      _farmerIdLoading = true;
      _farmerIdError = null;
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
        _farmerIdLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _farmerIdError = e.toString();
        _farmerIdLoading = false;
      });
    }
  }


  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    // Basic validations
    if (_selectedFarmerId == null || _selectedFarmerId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Farmer / Field ID')),
      );
      return;
    }

    Future<List<String>> _orgPathUidsFor(String uid) async {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? const {};
      final List path = (data['orgPathUids'] ?? [uid]) as List;
      return path.map((e) => e.toString()).toList();
    }


    final auth = context.read<AuthService>();
    final uid = context.read<AuthService>().uid;

    final createdBy = uid;
    final orgPathUids = await _orgPathUidsFor(createdBy ?? 'anon');

    final meta = await AuditMeta.build(context as AuthService);



    final payload = <String, dynamic>{
    'date': Timestamp.fromDate(_date),
    'farmerOrFieldId': _selectedFarmerId ?? '',
    'cropStage': _cropStageCtrl.text.trim(),
    'issue': _issuesCtrl.text.trim(),
    'recommendation': _recommendCtrl.text.trim(),
    'createdBy': createdBy,
    'orgPathUids': orgPathUids, // for subtree visibility (managers, etc.)
    'createdAt': FieldValue.serverTimestamp(),

    ...meta, // <-- add this
    };

    await FirebaseFirestore.instance
        .collection('field_diagnostics')
        .add(payload);


    try {
      await context.read<FieldDiagnosticsProvider>().add(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field Diagnostic saved')),
      );
      // Clear light-weight fields to speed up repeated entries
      setState(() {
        _issuesCtrl.clear();
        _recommendCtrl.clear();
        // keep date / farmer / crop stage for quicker multiple entries
      });
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Diagnostics'),
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
            // 1) View saved FIRST, so it’s always visible
            IconButton(
              icon: const Icon(Icons.list_alt_outlined),
              tooltip: 'View saved',
              onPressed: () => context.push('/fields/field/diagnostics/saved'),
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
      body: SingleChildScrollView(
        padding: _pagePad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SECTION: Meta / Date
            _Section(
              title: 'Meta',
              child: Column(
                children: [
                  _LabeledBox(
                    label: 'Date',
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(_ymd(_date)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // SECTION: Farmer / Field ID
            _Section(
              title: 'Farmer / Field',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledBox(
                    label: 'Farmer / Field ID',
                    child: DropdownButtonFormField<String>(
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
                  ),
                ],
              ),
            ),

            // SECTION: Crop & Stage
            _Section(
              title: 'Crop & Stage',
              child: _LabeledBox(
                label: 'Crop / Stage',
                child: TextField(
                  controller: _cropStageCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Maize - Vegetative',
                  ),
                ),
              ),
            ),

            // SECTION: Diagnostics
            _Section(
              title: 'Diagnostics',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledBox(
                    label: 'Issues / Observations',
                    child: TextField(
                      controller: _issuesCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Describe the problem / observation',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledBox(
                    label: 'Recommendations / Next Action',
                    child: TextField(
                      controller: _recommendCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Suggested remedy, next visit plan, etc.',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Padding(
              padding: _secPad,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Diagnostic'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple titled section card
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Label above any form field
class _LabeledBox extends StatelessWidget {
  const _LabeledBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label,
              style: Theme.of(context).textTheme.labelLarge),
        ),
        child,
      ],
    );
  }
}
