// lib/features/fields/field_observations_screen.dart (clean rewrite)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

// ⚠️ Adjust this import if your Observation model lives elsewhere
import '../../core/models/observation.dart';
import '../../core/models/farmer.dart';
import '../../core/services/audit_meta.dart';
import '../../core/services/farmers_provider.dart';

import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart'; // ← adjust path if your AuthService lives elsewhere

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/field_observations_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'field_observations_list_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';


/// Top-level helper to hold per-category table cells
class _CatDetail {
  final TextEditingController problemIdenitied = TextEditingController();
  final TextEditingController severityPercent = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  Map<String, String> toJson() => {
    'problemIdentified': problemIdenitied.text.trim(),
    'severityPercent': severityPercent.text.trim(),
    'remarks': remarks.text.trim(),
  };
}

class FieldObservationsScreen extends StatefulWidget {
  final String? defaultFarmerId;
  const FieldObservationsScreen({super.key, this.defaultFarmerId});

  @override
  State<FieldObservationsScreen> createState() => _FieldObservationsScreenState();
}

class _FieldObservationsScreenState extends State<FieldObservationsScreen> {
  // Form + meta
  final _formKey = GlobalKey<FormState>();
  final _date = ValueNotifier<DateTime>(DateTime.now());
  final _farmerIdCtrl = TextEditingController();
  List<String> _farmerIds = [];
  String? _selectedFarmerId;

  final _cropStageCtrl = TextEditingController();

  // Categories as checkboxes
  final List<String> _categories = const [
    'Disease',
    'Pest',
    'Weed',
    'Nutrient',
    'Water',
    //'Crop damage',
    'Problem Idenitied',
  ];
  late final Map<String, bool> _selectedCats;
  late final Map<String, _CatDetail> _catDetails;

  // Problem + severity + action
  final _problemCtrl = TextEditingController();
  int _severity = 0;
  final _actionCtrl = TextEditingController();

  // AI fields (mock)
  int? _aiConfidence;
  String? _aiRecommendedAction;
  final _aiConfCtrl = TextEditingController();
  final _aiActionCtrl = TextEditingController();

  // Attachments
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  bool get _photosAttached => _photos.isNotEmpty;
  XFile? _consentPhoto;

  // Follow up / GPS / remarks / signature
  DateTime? _followUpDate;
  String? _gpsCheckin; // if you have a string location, we convert to bool when saving
  final _remarksCtrl = TextEditingController();
  final SignatureController _sig = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _signaturePng;

  @override
  void initState() {
    super.initState();
    _loadFarmerIdItems();
    _selectedCats = {for (final c in _categories) c: false};
    _catDetails = {for (final c in _categories) c: _CatDetail()};
    _initFarmerId();
    // Also load cached farmer IDs from SharedPreferences and merge with provider list
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('farmers_cache_ids') ?? <String>[];
        final prov = context.read<FarmersProvider>().farmers.map((f) => f.id).toList(growable: false);
        final setIds = <String>{...cached, ...prov};
        if (mounted) setState(() { _farmerIds = setIds.toList()..sort(); });
      } catch (_) {}
    });
  }

  Future<void> _initFarmerId() async {
    if (widget.defaultFarmerId != null && widget.defaultFarmerId!.isNotEmpty) {
      _farmerIdCtrl.text = widget.defaultFarmerId!;
      return;
    }
    final sp = await SharedPreferences.getInstance();
    _farmerIdCtrl.text = sp.getString('last_field_id') ?? '';
  }

  @override
  void dispose() {
    _date.dispose();
    _farmerIdCtrl.dispose();
    _cropStageCtrl.dispose();
    for (final d in _catDetails.values) {
      d.problemIdenitied.dispose();
      d.severityPercent.dispose();
      d.remarks.dispose();
    }
    _problemCtrl.dispose();
    _actionCtrl.dispose();
    _aiConfCtrl.dispose();
    _aiActionCtrl.dispose();
    _remarksCtrl.dispose();
    _sig.dispose();
    super.dispose();
  }

  void _mockSendToRoles(Observation obs, List<String> roles) {
    // TODO: replace with your real submit (API / Firestore / email, etc.)
    debugPrint('Submitting observation to $roles => ${jsonEncode(obs)}');
  }


  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _photos.addAll(picked));
  }

  Future<void> _pickConsentPhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo != null) setState(() => _consentPhoto = photo);
  }

  Future<void> _exportSignature() async {
    if (_sig.isEmpty) {
      _signaturePng = null;
      return;
    }
    _signaturePng = await _sig.toPngBytes();
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


  void _runAIMock() {
    final hasPhotos = _photosAttached;
    final selected = _selectedCats.entries.where((e) => e.value).map((e) => e.key).toList();

    final rec = selected.contains('Disease')
        ? 'Apply recommended fungicide as per label; monitor for 7 days.'
        : selected.contains('Pest')
        ? 'Consider IPM: scouting + threshold-based spray.'
        : 'No specific action; continue monitoring.';

    final conf = hasPhotos ? 85 : 60;

    setState(() {
      _aiConfidence = conf;
      _aiRecommendedAction = rec;
      _aiConfCtrl.text = '$conf%';
      _aiActionCtrl.text = rec;
    });

    FocusScope.of(context).unfocus();
  }

  Future<List<String>> _orgPathUidsFor(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? const {};
    final List path = (data['orgPathUids'] ?? [uid]) as List;
    return path.map((e) => e.toString()).toList();
  }

  Future<void> _saveToFirestore() async {

    final auth = context.read<AuthService>();
    final createdBy = auth.currentUser?.uid ?? 'anon';
    final orgPathUids = await _orgPathUidsFor(createdBy);
    try {
      // Collect values from your existing controllers/fields.
      // Adjust controller names if yours differ.
      final String farmerId =
      (_farmerIdCtrl.text.isNotEmpty ? _farmerIdCtrl.text : (_selectedFarmerId ?? '')).trim();
      final String cropStage = (_cropStageCtrl?.text ?? '').trim(); // if you named it differently, adjust

      final auth = context.read<AuthService>();
      final meta = await AuditMeta.build(auth);

      final payload = <String, dynamic>{
        'date': Timestamp.fromDate(_date.value),                // you already use ValueNotifier<DateTime>
        'farmerOrFieldId': farmerId,
        'cropStage': cropStage,

        // audit
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'orgPathUids': orgPathUids, // for subtree visibility (managers, etc.)
        'createdAt': FieldValue.serverTimestamp(),
        ...meta, // <-- add this
      };

      await FirebaseFirestore.instance.collection('field_observations').add(payload);

      await context.read<FieldObservationsProvider>().addObservation(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observation saved')),
      );

      // Reset the form (adjust controllers you actually have)
      _formKey.currentState?.reset();
      _selectedFarmerId = null;
      _farmerIdCtrl.clear();
      _cropStageCtrl?.clear();

      setState(() {}); // refresh chips / selections
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }


  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? true;
    if (!isValid) return;

    try {
      final farmerId = ((_selectedFarmerId ?? _farmerIdCtrl.text).trim());

      final payload = <String, dynamic>{
        'date'            : Timestamp.fromDate(_date.value), // your ValueNotifier<DateTime>
        'farmerOrFieldId' : farmerId,
        'cropStage'       : _cropStageCtrl.text.trim(), // if your field is named differently, use that
        'createdAt'       : FieldValue.serverTimestamp(),
        'createdBy'       : FirebaseAuth.instance.currentUser?.uid ?? '',
      };

      await context.read<FieldObservationsProvider>().addObservation(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observation saved')),
      );

      // clear only the fields you actually have
      _formKey.currentState?.reset();
      _farmerIdCtrl.clear();
      _cropStageCtrl.clear();
      _selectedFarmerId = null;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }



  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final selected = _selectedCats.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Observation Category.')),
      );
      return;
    }

    for (final cat in selected) {
      final d = _catDetails[cat]!;
      if (d.problemIdenitied.text.trim().isEmpty ||
          d.severityPercent.text.trim().isEmpty ||
          d.remarks.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields for "$cat".')),
        );
        return;
      }
      final p = double.tryParse(d.severityPercent.text.trim());
      if (p == null || p < 0 || p > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selection(%) for "$cat" must be 0–100.')),
        );
        return;
      }
    }

    await _exportSignature();

    final joinedCategories = selected.join(', ');
    final tableJson = {for (final cat in selected) cat: _catDetails[cat]!.toJson()};

    // ✅ Same fix here:
    final appendedRemarks = (_remarksCtrl.text.trim().isEmpty
        ? ''
        : _remarksCtrl.text.trim() + '\n\n') +
        '[CategoryDetails] ' +
        jsonEncode(tableJson);

    final obs = Observation(
      date: _date.value,
      farmerId: _farmerIdCtrl.text.trim(),
      cropAndStage: _cropStageCtrl.text.trim(),
      category: joinedCategories,
      problemIdentified: _problemCtrl.text.trim(),
      severity: _severity,
      actionRecommended: _actionCtrl.text.trim(),
      photosAttached: _photosAttached,
      aiConfidence: _aiConfidence,
      aiRecommendedAction: _aiRecommendedAction,
      followUpDate: _followUpDate,
      gpsCheckin: _gpsCheckin != null,
      remarks: appendedRemarks.isEmpty ? null : appendedRemarks,
      consentPhotoPath: _consentPhoto?.path,
      signaturePngBase64: _signaturePng == null ? null : base64Encode(_signaturePng!),
      attachmentPaths: _photos.map((e) => e.path).toList(),
    );


    // Submit to Territory Incharge, Customer Support, Cluster Incharge, Manager
    _mockSendToRoles(obs, const [
      'territory_incharge',
      'customer_support',
      'cluster_incharge',
      'manager',
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Observation submitted to Territory, Customer Support, Cluster & Manager')),
    );
    Navigator.pop(context, obs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
		  appBar: AppBar(
			title: const Text('Field Observations'),
			leading: IconButton(
			  icon: const Icon(Icons.arrow_back),
			  tooltip: 'Back',
			  onPressed: () {
				if (Navigator.of(context).canPop()) {
				  Navigator.of(context).pop();
				  return;
				}
				// Fallback when this page is the root:
				context.go('/');              // or your real path, e.g. context.go('/farmer-network')
				// or: context.goNamed('home');
		   },
		),
        actions: [
          // 1) View saved FIRST, so it’s always visible
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'View saved',
            onPressed: () => context.push('/fields/observations/saved'),
            // or: Navigator.of(context).push(MaterialPageRoute(
            //   builder: (_) => const FieldObservationsListScreen(),
            // ));
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

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(
                  title: 'Meta',
                  children: [
                    // Date, then Farmer/Field ID (full width), then Crop & Stage comes after this block
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DateField(label: 'Date', valueListenable: _date),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _farmerId,
                          items: _farmerIdItems,                 // <- list built above
                          onChanged: (v) => setState(() => _farmerId = v),
                          decoration: const InputDecoration(
                            labelText: 'Farmer / Field ID',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cropStageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Crop & Stage',
                        hintText: 'e.g., Maize – Vegetative',
                        border: OutlineInputBorder(),
                      ),
                      validator: (t) => (t == null || t.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _card(
                  title: 'Observation Categories & Details',
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final cat in _categories)
                          FilterChip(
                            selected: _selectedCats[cat]!,
                            label: Text(cat),
                            onSelected: (v) => setState(() => _selectedCats[cat] = v),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedCats.values.any((v) => v)) _buildCategoryTable(),
                  ],
                ),

                const SizedBox(height: 12),

                /*_card(
                  title: 'Problem & Severity',
                  children: [
                    TextFormField(
                      controller: _problemCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Problem Identified',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Severity:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _severity.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: '$_severity',
                            onChanged: (v) => setState(() => _severity = v.round()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),*/
                _card(
                  title: 'Attachments',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickPhotos,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Add Photos'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickConsentPhoto,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: const Text('Consent Photo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_photos.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_photos[i].path),
                                  width: 110,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () => setState(() => _photos.removeAt(i)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(.5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),
                TextFormField(
                  controller: _cropStageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Action Recommended',
                    border: OutlineInputBorder(),
                  ),
                  validator: (t) => (t == null || t.trim().isEmpty) ? 'Required' : null,
                ),


                const SizedBox(height: 12),

                _card(
                  title: 'Action',
                  children: [
                   /* TextFormField(
                      controller: _actionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Action Recommended',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),*/
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _runAIMock,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run AI (mock) from photos + inputs'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _aiConfCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'AI Confidence',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _aiActionCtrl,
                            readOnly: true,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'AI Recommended Action',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    /*const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _runAIMock,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run AI (mock) from photos + inputs'),
                      ),
                    ),*/
                  ],
                ),

                const SizedBox(height: 12),

                /*_card(
                  title: 'Attachments',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickPhotos,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Add Photos'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickConsentPhoto,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: const Text('Consent Photo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_photos.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_photos[i].path),
                                  width: 110,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () => setState(() => _photos.removeAt(i)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(.5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),*/

                const SizedBox(height: 12),

                _card(
                  title: 'Signature & Misc',
                  children: [
                    SizedBox(
                      height: 160,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Signature(controller: _sig, backgroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sig.clear(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Clear Signature'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                initialDate: _followUpDate ?? DateTime.now(),
                              );
                              if (picked != null) setState(() => _followUpDate = picked);
                            },
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(
                              _followUpDate == null
                                  ? 'Set Follow-up Date'
                                  : 'Follow-up: ${_followUpDate!.toIso8601String().split('T').first}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save Observation'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit to Territory/CS/Cluster/Manager'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTable() {
    final selected = _selectedCats.entries.where((e) => e.value).map((e) => e.key).toList();
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF6F6F6)),
          children: [
            _TableHeader('Category'),
            _TableHeader('ProblemIdentified'),
            _TableHeader('Severity(%)'),
            _TableHeader('Remarks'),
          ],
        ),
        for (final cat in selected)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _catDetails[cat]!.problemIdenitied,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _catDetails[cat]!.severityPercent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), suffixText: '%'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final p = double.tryParse(v.trim());
                    if (p == null || p < 0 || p > 100) return '0–100';
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _catDetails[cat]!.remarks,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
      ],
    );
  }


  // Farmer ID autocomplete using FarmersProvider list
  Widget _farmerIdAutocomplete() {
    final farmers = context.watch<FarmersProvider>().farmers;
    return Autocomplete<Farmer>(
      optionsBuilder: (TextEditingValue tev) {
        final q = tev.text.trim().toLowerCase();
        if (q.isEmpty) {
          // show all (cap to avoid giant panels)
          return farmers.take(50);
        }
        return farmers.where((f) {
          final id = f.id.toLowerCase();
          final name = (f.name ?? '').toLowerCase();
          final village = (f.cropVillage ?? '').toLowerCase();
          final phone = (f.phone ?? '');
          return id.contains(q) || name.contains(q) || village.contains(q) || phone.contains(q);
        }).take(50);
      },
      displayStringForOption: (f) => f.id,
      onSelected: (f) {
        _farmerIdCtrl.text = f.id;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // use our controller so validation integrates with the form
        controller.text = _farmerIdCtrl.text;
        controller.selection = _farmerIdCtrl.selection;
        controller.addListener(() {
          if (controller.text != _farmerIdCtrl.text) {
            _farmerIdCtrl.text = controller.text;
            _farmerIdCtrl.selection = controller.selection;
          }
        });
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Farmer / Field ID',
            border: OutlineInputBorder(),
            hintText: 'Search by ID, name, village, or phone',
          ),
          validator: (t) => (t == null || t.trim().isEmpty) ? 'Required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32, // align to field width-ish
              height: opts.length > 6 ? 280 : (opts.length * 48).toDouble(),
              child: ListView.builder(
                itemCount: opts.length,
                itemBuilder: (_, i) {
                  final f = opts[i];
                  return ListTile(
                    dense: true,
                    title: Text(f.id),
                    subtitle: Text([
                      if ((f.name ?? '').isNotEmpty) f.name!,
                      if ((f.cropVillage ?? '').isNotEmpty) f.cropVillage!,
                      if ((f.phone ?? '').isNotEmpty) f.phone!,
                    ].join(' • ')),
                    onTap: () => onSelected(f),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, top: 6),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final ValueNotifier<DateTime> valueListenable;
  const _DateField({required this.label, required this.valueListenable});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: valueListenable,
      builder: (context, v, _) {
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: v,
            );
            if (picked != null) valueListenable.value = picked;
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            child: Text(v.toIso8601String().split('T').first),
          ),
        );
      },
    );
  }
}