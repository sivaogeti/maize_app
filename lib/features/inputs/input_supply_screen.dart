
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../core/services/auth_service.dart';

import 'package:intl/intl.dart';         // if _ymd is not already available
import 'dart:typed_data' hide Uint8List;

import 'package:image_picker/image_picker.dart';

import 'dart:typed_data'; // for Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';




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

  // Inside _InputSupplyScreenState:

  Uint8List? _farmerPhotoBytes;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Future<void> _saveToFirestore() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Ensure user is available
      final user = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null);
      final createdBy = user!.uid;

      // Collect values from your UI. If you later wire TextEditingControllers, use them here.
      final String? farmerId = (_selectedFarmerOrFieldId?.trim().isEmpty ?? true)
          ? null
          : _selectedFarmerOrFieldId!.trim();

      final DateTime date = DateTime.now(); // replace with your selected date if you store one
      final String docId = _buildDocId(date: date, createdBy: createdBy, farmerId: farmerId);

      String? farmerPhotoUrl;
      String? signatureUrl;

      String safeDocId = docId.replaceAll(RegExp(r'[^\w\-]'), '_');

      // Upload farmer photo
      if (_farmerPhotoBytes != null && _farmerPhotoBytes!.isNotEmpty) {
        final ref = FirebaseStorage.instance.ref().child('input_supply_photos/$safeDocId.jpg');
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        await ref.putData(_farmerPhotoBytes!, metadata);
        farmerPhotoUrl = await ref.getDownloadURL();
      }

      // Upload signature
      if (_farmerSignatureBytes != null && _farmerSignatureBytes!.isNotEmpty) {
        final ref = FirebaseStorage.instance.ref().child('signatures/$safeDocId.png');
        final metadata = SettableMetadata(contentType: 'image/png');
        await ref.putData(_farmerSignatureBytes!, metadata);
        signatureUrl = await ref.getDownloadURL();
      }



      // Build data map. Add any other fields you have (brand, qty, uom, itemType, attachments, signature).
      final Map<String, dynamic> data = {
        'farmerId': farmerId,
        //'createdBy': createdBy,
        'createdBy': user.uid,
        'orgPathUids': [user.uid],       // required for creatingInOwnOrg()
        'createdAt': FieldValue.serverTimestamp(),
        'localCreatedAt': date.toIso8601String(),
        //'receivedByFarmer': _receivedByFarmer,
        // placeholder fields - replace with real values from controllers when added:
        'itemType': 'Fertiliser',
        'brandOrGrade': null,
        'batchNo': null,
        'uom': null,
        'quantity': null,
        'farmerPhotoUrl': farmerPhotoUrl,
        'signatureUrl': signatureUrl,
        'source': 'input_supply_screen',
      };

      final db = FirebaseFirestore.instance;

      // Write using set() (merging false) — change to update() if doc already exists
      await db.collection('input_supplies').doc(docId).set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Firestore (docId: $docId)')),
      );

      // Optionally save last docId for later navigation
      setState(() => _lastSavedDocId = docId);
    } on FirebaseException catch (e) {
      // Firestore-specific errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore error: ${e.code} — ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      //const SizedBox(height: 12),
                      //_receivedBySwitch(),
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
    const items = ['Cluster Incharge', 'Territory Incharge'];
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
          onPressed: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.camera);
            if (picked != null) {
              _farmerPhotoBytes = await picked.readAsBytes();
              setState(() {});
            }
          },
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
            image: _farmerPhotoBytes != null
                ? DecorationImage(
              image: MemoryImage(_farmerPhotoBytes!),
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: _farmerPhotoBytes == null
              ? const Icon(Icons.image, size: 40)
              : null,
        ),
      ],
    );
  }


  Uint8List? _farmerSignatureBytes; // Add this to your State

  Widget _signatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Farmer Signature', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          height: 220,
          child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _signatureController.clear();
                setState(() {
                  _farmerSignatureBytes = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Signature'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                if (_signatureController.isNotEmpty) {
                  final signatureBytes = await _signatureController.toPngBytes();
                  if (signatureBytes != null) {
                    setState(() {
                      _farmerSignatureBytes = signatureBytes;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signature captured!')),
                    );
                  }
                }
              },
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
