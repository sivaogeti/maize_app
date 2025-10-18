
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

import 'package:intl/intl.dart';         // if _ymd is not already available


String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);


String _buildDocId({
  required DateTime date,
  required String createdBy,
  String? farmerId,
}) =>
    '${(farmerId ?? createdBy)}_${_ymd(date)}';

class InputSupplyScreen extends StatefulWidget {
  const InputSupplyScreen({super.key});

  @override
  State<InputSupplyScreen> createState() => _InputSupplyScreenState();
}

class _InputSupplyScreenState extends State<InputSupplyScreen> {

  // Fake farmer selection; wire to your provider later.
  String? _selectedFarmer;

  bool _saving = false;
  bool _receivedByFarmer = false;
  String? _selectedFarmerOrFieldId;

  final _signatureKey = GlobalKey();

  String? _lastSavedDocId;

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

  Future<void> _saveToFirestore() async {
    if (_saving) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved (demo)')),
    );
  }

  void _openDetails() {
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Details'),
        content: Text('Open InputsDetailsScreen here.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Supply Screen'),
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
          /*IconButton(
            tooltip: 'View details',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: _openDetails,
          ),*/
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'View saved',
            onPressed: () {
              final auth = context.read<AuthService>();
              final createdBy = auth.currentUser?.uid ?? auth.currentUserId ?? 'anon';

              // use the same farmer selection and date you used when saving
              final String? farmerId = (_selectedFarmer?.trim().isEmpty ?? true)
                  ? null
                  : _selectedFarmer!.trim();
              final DateTime date = DateTime.now(); // or your page date

              final docId = _buildDocId(date: date, createdBy: createdBy, farmerId: farmerId);
              context.goNamed('fi.inputs.detail', pathParameters: {'docId': docId});
            },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveToFirestore,
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Save'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _farmerFieldIdDropdown(),
                      const SizedBox(height: 12),
                      _datePickerField(),
                      const SizedBox(height: 12),
                      _cropAndStageField(),
                      const SizedBox(height: 12),
                      _itemTypeField(),
                      const SizedBox(height: 12),
                      _brandBatchRow(),
                      const SizedBox(height: 12),
                      _uomQtyRow(),
                      const SizedBox(height: 12),
                      _issuerDropdown(),
                      const SizedBox(height: 12),
                      _receivedBySwitch(),
                      const SizedBox(height: 12),
                      _attachmentsRow(),
                      const SizedBox(height: 16),
                      _signatureSection(),
                      const SizedBox(height: 16),
                      //_financeAndRemarks(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== stubs (replace with your real fields) =====

  Widget _farmerFieldIdDropdown() {
    final items = const [
      'FR_cumbum_osfarmer1_316',
      'FN_cumbum_osfarmer4_66',
      'FR_cumbum_osfarmer5_220',
    ];
    return DropdownButtonFormField<String>(
      value: _selectedFarmerOrFieldId,
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _selectedFarmerOrFieldId = v),
      decoration: const InputDecoration(
        labelText: 'Farmer / Field ID',
        prefixIcon: Icon(Icons.badge_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _datePickerField() {
    final now = DateTime.now();
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'),
      decoration: const InputDecoration(
        labelText: 'Date',
        prefixIcon: Icon(Icons.event),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _cropAndStageField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Crop & Stage',
        prefixIcon: Icon(Icons.agriculture),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _itemTypeField() {
    return DropdownButtonFormField<String>(
      value: 'Fertiliser',
      items: const [
        DropdownMenuItem(value: 'Fertiliser', child: Text('Fertiliser')),
        DropdownMenuItem(value: 'Seed', child: Text('Seed')),
        DropdownMenuItem(value: 'Pesticide', child: Text('Pesticide')),
      ],
      onChanged: (_) {},
      decoration: const InputDecoration(
        labelText: 'Item Type',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _brandBatchRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Brand / Grade',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Batch / Lot No.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uomQtyRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Unit of Measure',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Quantity issued',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _issuerDropdown() {
    const items = ['Field Incharge', 'Cluster Incharge', 'Territory Incharge'];
    return DropdownButtonFormField<String>(
      value: items.first,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (_) {},
      decoration: const InputDecoration(
        labelText: 'Issuer By (Cluster/Territory incharge/manager)',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _receivedBySwitch() {
    return SwitchListTile.adaptive(
      title: const Text('Received By (Farmer Sign / Photo)'),
      value: _receivedByFarmer,
      onChanged: (v) => setState(() => _receivedByFarmer = v),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _attachmentsRow() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Farmer Photo'),
        ),
        const SizedBox(width: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.image, size: 40),
        ),
      ],
    );
  }

  Widget _signatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Signature', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          key: _signatureKey,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('Signature Pad Placeholder')),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.clear),
              label: const Text('Clear Signature'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.check),
              label: const Text('Use'),
            ),
          ],
        ),
      ],
    );
  }

  /*Widget _financeAndRemarks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Finance & Remarks', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Advance amount',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity issued',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }*/
}
