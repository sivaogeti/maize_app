import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/farmers_provider.dart';
import '../../core/models/farmer.dart';
import '../../core/widgets/role_guard.dart';

import 'package:provider/provider.dart';
import 'package:app_clean/core/services/auth_service.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// lib/features/farmers/farmer_network_screen.dart (top of file)
const List<String> kSoilTypes = <String>[
  'Alluvial','Alkaline','Arid','Black','Forest','Laterite','Peaty','Marshy','Red','Yellow',
];

const List<String> kSoilTextures = <String>[
  'Black','Red','Sand','Stone Mix'
];

const List<String> kWaterSources = <String>[
  'Canal','BoreWell-2 Inches','BoreWell-3 Inches','BoreWell-4 IonSowingTypeChangednches'
];

final List<Map<String, dynamic>> _sowingTypes = [
  {'label': 'Single', 'icon': 'assets/icons/maize_single.png'},
  {'label': 'Dual', 'icon': 'assets/icons/maize_dual.png'},
];

/// Farmer Network: List all linked farmers & land agreements,
/// quick filter by cluster/territory, and a button to initiate a new agreement.
class FarmerNetworkScreen extends StatefulWidget {
  const FarmerNetworkScreen({super.key});

  @override
  State<FarmerNetworkScreen> createState() => _FarmerNetworkScreenState();
}

class _FarmerNetworkScreenState extends State<FarmerNetworkScreen> {
  final TextEditingController _search = TextEditingController();

  String? _cluster;
  String? _territory;

  String _sowingType = 'Single'; // <- the single source of truth

  // at state level
  String? _soilType;
  
  String? _soilTexture;

  // Farmer-level extra filters/fields
  final TextEditingController _surveyCtrl = TextEditingController();
  final TextEditingController _sowingDateCtrl = TextEditingController();


  bool _dualFemale = false;
  bool _dualMale = false;
  @override
  void initState() {
    super.initState();
    void rebuild() => setState(() {});
    _search.addListener(rebuild);
    _surveyCtrl.addListener(rebuild);
    _sowingDateCtrl.addListener(rebuild);
  }


  @override
  void dispose() {
    _search.dispose();
    _surveyCtrl.dispose();
    _sowingDateCtrl.dispose();
    super.dispose();
  }

  // AppBar with Back when we can pop; Menu otherwise + Logout
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Farmer Network'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
		  tooltip: 'Back',
		  onPressed: () {
			if (context.canPop()) {
			  context.pop();
			  return;
			}
			// Fallback when this page is root:
			context.go('/'); // or context.goNamed('home');
		},
      ),
      actions: [
        // 1) View saved FIRST, so it’s always visible
        IconButton(
          icon: const Icon(Icons.list_alt),
          tooltip: 'View saved',
          onPressed: () => context.push('/farmers/farmers/saved'),
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
    );
  }

  void _openCreateAgreementSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _NewAgreementSheet(
        onCreate: (f) {
          context.read<FarmersProvider>().addFarmer(f);
          Navigator.pop(ctx);

          // Align filters to new farmer so it appears in the list immediately
          setState(() {
            _cluster = (f.cluster == null || f.cluster!.isEmpty) ? 'All' : f.cluster;
            _territory = (f.territory == null || f.territory!.isEmpty) ? 'All' : f.territory;
            _search.clear();
            _surveyCtrl.clear();
            _sowingDateCtrl.clear();
            _sowingType = 'Single';
            _dualFemale = false;
            _dualMale = false;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Farmer created: ${f.id}')),
          );
        },
      ),
    );
  }

  void _showFarmerDetails(Farmer f) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Farmer Details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _kv('ID', f.id),
                  _kv('Name', f.name),
                  _kv('Phone', f.phone),
                  const Divider(),
                  _kv('Residence Village', f.residenceVillage ?? ''),
                  _kv('Crop Village', f.cropVillage ?? ''),
                  _kv('Cluster', f.cluster ?? ''),
                  _kv('Territory', f.territory ?? ''),
                  const Divider(),
                  _kv('Season', f.season ?? ''),
                  //_kv('Hybrid', f.hybrid ?? ''),
                  _kv('Proposed AreaProposed Area', f.plantedArea?.toString() ?? ''),
                  _kv('Water Source', f.waterSource ?? ''),
                  _kv('Previous Crop', f.previousCrop ?? ''),
                  //_kv('Soil Type', f.soilType ?? ''),
                  _kv('Soil Texture', f.soilTexture ?? ''),
                  const SizedBox(height: 12),
                  if ((f.photoPath ?? '').isNotEmpty) ...[
                    Text('Photo', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(f.photoPath!), height: 140, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: _buildAppBar(context),
        drawer: _DrawerMaybe(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateAgreementSheet,
          icon: const Icon(Icons.post_add),
          label: const Text('New Agreement'),
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _HeaderCard(
              searchController: _search,
              cluster: _cluster,
              territory: _territory,
              onClusterChanged: (v) => setState(() => _cluster = v),
              onTerritoryChanged: (v) => setState(() => _territory = v),

              // NEW props
              surveyCtrl: _surveyCtrl,
              sowingDateCtrl: _sowingDateCtrl,
              sowingType: _sowingType,
              onSowingTypeChanged: (v) => setState(() {
                _sowingType = v ?? 'Single';
                if (_sowingType != 'Dual') {
                  _dualFemale = false;
                  _dualMale = false;
                }
              }),
              dualFemale: _dualFemale,
              dualMale: _dualMale,
              onDualFemaleChanged: (v) => setState(() => _dualFemale = v ?? false),
              onDualMaleChanged: (v) => setState(() => _dualMale = v ?? false),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: Consumer<FarmersProvider>(
                builder: (_, fp, __) {
                  final q = _search.text.trim().toLowerCase();
                  final surveyQ = _surveyCtrl.text.trim();
                  final sowTimeQ = _sowingDateCtrl.text.trim();

                  final items = fp.farmers.where((f) {
                    bool ok = true;

                    String norm(String? s) => (s ?? '').trim().toLowerCase();

                    // Cluster / Territory (ignore when 'All' is selected)
                    if (_cluster != null && norm(_cluster) != 'all' && _cluster!.isNotEmpty) {
                      ok &= norm(f.cluster ?? '') == norm(_cluster);
                    }
                    if (_territory != null && norm(_territory) != 'all' && _territory!.isNotEmpty) {
                      ok &= norm(f.territory ?? '') == norm(_territory);
                    }

                    // Free-text search: include ID, name, phone, villages, hybrid
                    if (q.isNotEmpty) {
                      final hay = <String>[
                        f.id ?? '',
                        f.name ?? '',
                        f.phone ?? '',
                        f.residenceVillage ?? '',
                        f.cropVillage ?? '',
                        //f.hybrid ?? '',
                      ].map((s) => s.toLowerCase());
                      ok &= hay.any((s) => s.contains(q));
                    }

                    // Extra filters encoded in previousCrop text
                    final pc = (f.previousCrop ?? '');
                    if (surveyQ.isNotEmpty) {
                      ok &= pc.contains('Survey:$surveyQ');
                    }
                    if (sowTimeQ.isNotEmpty) {
                      ok &= pc.contains('sowingDate:$sowTimeQ');
                    }

                    if (_sowingType == 'Single') {
                      ok &= pc.contains('SowingType:Single');
                    } else if (_sowingType == 'Dual') {
                      ok &= pc.contains('SowingType:Dual');
                      if (_dualFemale) ok &= pc.contains('Female');
                      if (_dualMale) ok &= pc.contains('Male');
                    }

                    return ok;
                  }).toList();
                  if (items.isEmpty) {
                    return const _EmptyHint();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final f = items[i];
                      return _FarmerTile(
                        farmer: f,
                        onOpen: () => _showFarmerDetails(f),
                        onDelete: () {
                          context.read<FarmersProvider>().removeFarmer(f.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Removed ${f.name}')),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  // small helper for key/value rows in details sheet
  Widget _kv(String k, String v) {
    final styleKey = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: styleKey)),
          const SizedBox(width: 8),
          Expanded(child: Text(v.isEmpty ? '—' : v)),
        ],
      ),
    );
  }
}

// ============================ UI pieces ===================================

class _HeaderCard extends StatelessWidget {
  final TextEditingController searchController;
  final String? cluster;
  final String? territory;
  final ValueChanged<String?> onClusterChanged;
  final ValueChanged<String?> onTerritoryChanged;

  // NEW
  final TextEditingController surveyCtrl;
  final TextEditingController sowingDateCtrl;
  final String sowingType; // 'Single' | 'Dual'
  final ValueChanged<String?> onSowingTypeChanged;
  final bool dualFemale;
  final bool dualMale;
  final ValueChanged<bool?> onDualFemaleChanged;
  final ValueChanged<bool?> onDualMaleChanged;

  const _HeaderCard({
    required this.searchController,
    required this.cluster,
    required this.territory,
    required this.onClusterChanged,
    required this.onTerritoryChanged,
    required this.surveyCtrl,
    required this.sowingDateCtrl,
    required this.sowingType,
    required this.onSowingTypeChanged,
    required this.dualFemale,
    required this.dualMale,
    required this.onDualFemaleChanged,
    required this.onDualMaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Card(
        color: theme.colorScheme.surface.withOpacity(0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Linked Farmers & Land Agreements',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => (context as Element).markNeedsBuild(),
                      decoration: const InputDecoration(
                        hintText: 'Search by name, village, ID…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DropdownField(
                      icon: Icons.domain,
                      label: 'Cluster',
                      value: cluster,
                      items: const ['All','Narasaraopet', 'Guntur', 'Bapatla', 'Cumbum'],
                      onChanged: onClusterChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DropdownField(
                      icon: Icons.map_outlined,
                      label: 'Territory',
                      value: territory,
                      items: const ['All','North', 'South', 'East', 'West'],
                      onChanged: onTerritoryChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Survey No + Sowing Date
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: surveyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Survey No',
                        prefixIcon: Icon(Icons.tag_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: sowingDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sowing Date',
                        //hintText: 'e.g. 8:30 AM or Morning',
                        prefixIcon: Icon(Icons.calendar_today), // 📅 calendar icon
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Sowing Type + (conditional) Dual checkboxes
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: sowingType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sowing Type',
                        border: OutlineInputBorder(),
                        //isDense: true,
                        //prefixIcon: Icon(Icons.agriculture_outlined),
                      ),
                      items: _sowingTypes.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['label'],
                          child: Row(
                            children: [
                              Image.asset(item['icon'], width: 20, height: 20),
                              const SizedBox(width: 8),
                              Text(item['label']),
                            ],
                          ),
                        );
                      }).toList(),
                      //onChanged: onSowingTypeChanged,
                      onChanged: onSowingTypeChanged,  // <- call the callback
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: sowingType == 'Dual'
                        ? Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Female'),
                            value: dualFemale,
                            onChanged: onDualFemaleChanged,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Male'),
                            value: dualMale,
                            onChanged: onDualMaleChanged,
                          ),
                        ),
                      ],
                    )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No farmers yet. Tap “New Agreement” to add one.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FarmerTile extends StatelessWidget {
  final Farmer farmer;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _FarmerTile({
    required this.farmer,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : '?'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmer.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 12,
                    children: [
                      _chip(Icons.badge, farmer.id),
                      if (farmer.residenceVillage != null && farmer.residenceVillage!.isNotEmpty)
                        _chip(Icons.location_on_outlined, farmer.residenceVillage!),
                      if (farmer.cropVillage != null && farmer.cropVillage!.isNotEmpty)
                        _chip(Icons.location_on_outlined, farmer.cropVillage!),
                      if (farmer.cluster != null && farmer.cluster!.isNotEmpty)
                        _chip(Icons.domain, farmer.cluster!),
                      if (farmer.territory != null && farmer.territory!.isNotEmpty)
                        _chip(Icons.map_outlined, farmer.territory!),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ============================ New Agreement Sheet ==========================

class _NewAgreementSheet extends StatefulWidget {
  final ValueChanged<Farmer> onCreate;
  const _NewAgreementSheet({required this.onCreate});

  @override
  State<_NewAgreementSheet> createState() => _NewAgreementSheetState();
}

class _NewAgreementSheetState extends State<_NewAgreementSheet> {
  String? _soilType; // ← make it nullable

  String? _soilTexture; // ← make it nullable

  String? _waterSourceCtrl; // ← make it nullable

  final _formKey = GlobalKey<FormState>();


  //final String sowingType;

  // KYC / basic
  final _nameCtrl = TextEditingController();
  final _soCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Villages (split)
  final _resVillageCtrl = TextEditingController(); // residence village
  final _cropVillageCtrl = TextEditingController(); // crop village

  // Linking
  final _clusterCtrl = TextEditingController();
  final _territoryCtrl = TextEditingController();

  // Agreement
  String _season = 'Kharif';
  //final _hybridCtrl = TextEditingController();
  final _proposedAreaCtrl = TextEditingController();
  //String _soilType = 'Loamy';
  //String _soilType = 'wet(magani)';
  //String _soilTexture = 'black';
  //final _waterSourceCtrl = TextEditingController();
  final _previousCropCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  // NEW — requested fields
  final _surveyNoCtrl = TextEditingController();
  final _sowingDateCtrl = TextEditingController();
  String _sowingType = 'Single'; // Single | Dual
  bool _dualFemale = false;
  bool _dualMale = false;

  // Photo (picker)
  final ImagePicker _picker = ImagePicker();
  XFile? _photo;

  // Signature (draw + export)
  final SignatureController _sig = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _signaturePng;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _soCtrl.dispose();
    _phoneCtrl.dispose();
    _resVillageCtrl.dispose();
    _cropVillageCtrl.dispose();
    _clusterCtrl.dispose();
    _territoryCtrl.dispose();
    //_hybridCtrl.dispose();
    _proposedAreaCtrl.dispose();
    //_waterSourceCtrl.dispose();
    _previousCropCtrl.dispose();
    _surveyNoCtrl.dispose();
    _sowingDateCtrl.dispose();
    _sig.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _buildFarmerId() {
    final v = _cropVillageCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    final n = _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    final suffix = DateTime.now().millisecondsSinceEpoch % 1000;
    return 'FN_${v}_${n}_$suffix';
  }

  Future<void> _pickPhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    if (x != null) setState(() => _photo = x);
  }

  Future<void> _exportSignature() async {
    if (_sig.isNotEmpty) {
      final data = await _sig.toPngBytes();
      if (data != null) setState(() => _signaturePng = Uint8List.fromList(data));
    } else {
      setState(() => _signaturePng = null);
    }
  }


  Future<void> saveFarmer(BuildContext context, Map<String, dynamic> data) async {
    final db   = FirebaseFirestore.instance;
    final auth = context.read<AuthService>();

    final String uid = auth.currentUserIdOrAnon;
    final List<String> org = auth.orgPathUidList;

    // Normalise fields needed by your Firestore rules
    data['createdBy']   ??= uid;
    data['orgPathUids'] ??= (org.isNotEmpty ? org : <String>[uid]);
    data['createdAt']   ??= FieldValue.serverTimestamp();

    final String id = data['id'] as String;

    await db
        .collection('farmers')
        .orderBy('id')
        .startAt(const ['FN_'])
        .endAt(const ['FN_\uf8ff'])
        .snapshots();
        //.get(data as GetOptions?);
    //.doc(id)
    //.set(data, SetOptions(merge: true));

    // keep provider cache in sync (no refresh() needed)
    context.read<FarmersProvider>().addOrUpdateFromMap(data);
  }


  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _exportSignature();

    final id = _buildFarmerId();
    final area = double.parse(_proposedAreaCtrl.text.trim());

    final dualParts = <String>[];
    if (_sowingType == 'Dual') {
      if (_dualFemale) dualParts.add('Female');
      if (_dualMale) dualParts.add('Male');
    }
    final dualText = dualParts.isEmpty ? '' : ' (${dualParts.join('+')})';

    final prevCropWithExtras = [
      _previousCropCtrl.text.trim(),
      _remarksCtrl.text.trim(),
      'Survey:${_surveyNoCtrl.text.trim()}',
      'sowingDate:${_sowingDateCtrl.text.trim()}',
      'SowingType:${_sowingType}$dualText',
    ].where((s) => s.isNotEmpty).join(' | ');

    // --- build the model (NO FieldValue here) ---
    final data = <String, dynamic>{
      'id'               : id,
      'name'             : _nameCtrl.text.trim(),
      'sonof'            : _soCtrl.text.trim(),
      'phone'            : _phoneCtrl.text.trim(),
      'cropVillage'      : _cropVillageCtrl.text.trim(),
      'residenceVillage' : _resVillageCtrl.text.trim(),
      'cluster'          : _clusterCtrl.text.trim(),
      'territory'        : _territoryCtrl.text.trim(),
      'season'           : _season,
      //'hybrid'           : _hybridCtrl.text.trim(),
      'proposedArea'     : area,
      'waterSource'      : _waterSourceCtrl,
      'previousCrop'     : prevCropWithExtras,
      'soilType'         : _soilType,
      'soilTexture'         : _soilTexture,
      'photoPath'        : _photo?.path,
      'signaturePng'     : _signaturePng == null ? null : base64Encode(_signaturePng!),
      // these will be normalized in saveFarmer(...)
      'createdBy'        : FirebaseAuth.instance.currentUser?.uid,
      'createdAt'        : FieldValue.serverTimestamp(),
    };

    await saveFarmer(context, data);

    if (!mounted) return;
    Navigator.of(context).pop(); // or popUntil(...), your call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Farmer saved: $id')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('New Agreement',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Keep space on the right to balance the back button so title stays centered
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),

              // Basic
              _tf('Farmer Full name', _nameCtrl, required: true),
              _tf('S/o', _soCtrl, required: true),
              _tf('Phone', _phoneCtrl, type: TextInputType.phone, required: true),

              // Villages
              //_tf('Residence Village', _resVillageCtrl, required: true),
              TextFormField(
                controller: _resVillageCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.home_work_outlined, color: Colors.grey),
                  labelText: 'Residence Village',
                  border: OutlineInputBorder(),
                ),
              ),
              //_tf('Crop Village', _cropVillageCtrl, required: true),
              TextFormField(
                controller: _cropVillageCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.agriculture_outlined, color: Colors.grey),
                  labelText: 'Crop Village',
                  border: OutlineInputBorder(),
                ),
              ),

              // Survey No + Sowing Date
              Row(
                children: [
                  Expanded(
                    child: _tfIcon(
                      label: 'Survey No',
                      controller: _surveyNoCtrl,
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tfIcon(
                      label: 'Sowing Date',
                      controller: _sowingDateCtrl,
                      icon: Icons.calendar_today,
                      //hint: 'e.g. 8:30 AM or Morning',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Sowing Type + conditional Dual checkboxes
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sowingType,          // <- read from widget
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sowing Type',
                        border: OutlineInputBorder(),
                        //prefixIcon: Icon(Icons.agriculture_outlined),
                        //isDense: true,
                      ),
                      items: _sowingTypes
                          .map<DropdownMenuItem<String>>((item) => DropdownMenuItem<String>(
                        value: item['label'] as String,
                        child: Row(
                          children: [
                            Image.asset(item['icon'] as String, width: 20, height: 20),
                            const SizedBox(width: 8),
                            Text(item['label'] as String),
                          ],
                        ),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _soilType = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sowingType == 'Dual'
                        ? Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Female'),
                            value: _dualFemale,
                            onChanged: (v) => setState(() => _dualFemale = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Male'),
                            value: _dualMale,
                            onChanged: (v) => setState(() => _dualMale = v ?? false),
                          ),
                        ),
                      ],
                    )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

            /*  // Agreement: Season + Hybrid + Proposed Area
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                  value: _season,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Season',
                  ),
                  items: const ['Kharif', 'Rabi', 'Summer']
                      .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _season = v ?? _season),
                ),
              ),
              _tf('Hybrid (required)', _hybridCtrl, required: true),*/
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextFormField(
                  controller: _proposedAreaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Proposed Area (required)',
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Required';
                    final d = double.tryParse(t);
                    if (d == null || d <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
              ),

              // Soil Type
              //_tf('Soil Type', TextEditingController(text: _soilType)),
              // in build:
              DropdownButtonFormField<String>(
                value: _soilType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Soil Type',
				  prefixIcon: Icon(Icons.eco_outlined), // 🌿 eco/leaf icon
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select soil type'),
                items: kSoilTypes
                    .map<DropdownMenuItem<String>>(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                    .toList(),
                onChanged: (v) => setState(() => _soilType = v), // v is String?
                validator: (v) => v == null ? 'Please select a soil type' : null,
              ),
              const SizedBox(height: 12),
              // Soil Texture
              //_tf('Soil Texture', TextEditingController(text: _soilTexture)),
              DropdownButtonFormField<String>(
                value: _soilTexture,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Soil Texture',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select soil Texture'),
                items: kSoilTextures
                    .map<DropdownMenuItem<String>>(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                    .toList(),
                onChanged: (v) => setState(() => _soilType = v), // v is String?
                validator: (v) => v == null ? 'Please select a soil Texture' : null,
              ),
              const SizedBox(height: 12),
              // Water Source / Previous Crop
              //_tf('Water Source (required)', _waterSourceCtrl, required: true),
              DropdownButtonFormField<String>(
                value: _waterSourceCtrl,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Water Source',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select Water Source'),
                items: kWaterSources
                    .map<DropdownMenuItem<String>>(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                    .toList(),
                onChanged: (v) => setState(() => _soilType = v), // v is String?
                validator: (v) => v == null ? 'Please select Water Source' : null,
              ),
              const SizedBox(height: 12),
              _tf('Previous Crop (required)', _previousCropCtrl, required: true),
              const SizedBox(height: 12),
              // Photo picker + preview
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Farmer Photo'),
                  ),
                  const SizedBox(width: 12),
                  if (_photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_photo!.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Signature capture
              Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Signature(controller: _sig, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _sig.clear();
                      setState(() => _signaturePng = null);
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Signature'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _tf('Remarks', _remarksCtrl, required: true),

              const SizedBox(height: 12),
              SafeArea(
                top: false,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check),
                      label: const Text('Create'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tf(String label, TextEditingController c, {TextInputType? type, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: ' ',
        ).copyWith(labelText: label),
        validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _tfIcon({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          hintText: hint,
          isDense: true,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }
}

// Drawer stub so calling Scaffold.of(context).openDrawer() won’t throw if a drawer exists.
class _DrawerMaybe extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // If you already have a real AppDrawer widget, replace this with it
    return const SizedBox.shrink();
  }
}
