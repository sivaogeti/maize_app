// lib/features/farmers/registration_screen.dart
//
// Full file with Geo-polygon capture and the latest tweaks:
//
//  â€¢ Start adds initial point + live GPS stream (bestForNavigation)
//  â€¢ Tap-to-add points (even while recording)
//  â€¢ â€œAdd current pointâ€ ALWAYS adds a vertex (great on emulator)
//  â€¢ Stream threshold reduced to ~1 m so tiny moves still count
//  â€¢ Shows markers for every vertex
//  â€¢ Fits bounds on Finish + forces a harmless redraw (zoomBy 0)
//  â€¢ aadhar + photo, Bank no, Address, Sowing Date/Type (+Dual checkboxes)
//  â€¢ Back button (top-left) and Logout (top-right)
//
// If your project has different import paths for AuthService/Farmer/RoleGuard,
// adjust the three '../../core/...' imports below.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

// === Adjust these to your project paths ===
import '../../core/services/auth_service.dart';
import '../../core/models/farmer.dart';


// === Added: Registration list hub (search + New Registration FAB) ===
import '../../core/services/farmers_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/*const List<String> kSoilTypes = <String>[
  'Alluvial','Alkaline','Arid','Black','Forest','Laterite','Peaty','Marshy','Red','Yellow',
];*/

const List<String> kSoilTypes = <String>[
  'Wet(Magani)','Dry(Metta)',
];

const List<String> kSoilTextures = <String>[
  'Black','Red','Sand','Stone Mix'
];

const List<String> kWaterSources = <String>[
  'Canal','BoreWell-2 Inches','BoreWell-3 Inches','BoreWell-4 Inches','Lift'
];

final List<Map<String, dynamic>> _sowingTypes = [
  {'label': 'Single', 'icon': 'assets/icons/maize_single.png'},
  {'label': 'Dual', 'icon': 'assets/icons/maize_dual.png'},
];

// ===== Hub/List screen (Registration home like Network) =====

// Keep your RoleGuard removed if you already gate via router/login.

class FarmerRegistrationScreen extends StatefulWidget {
  const FarmerRegistrationScreen({super.key});

  @override
  State<FarmerRegistrationScreen> createState() => _FarmerRegistrationScreenState();
}

class _FarmerRegistrationScreenState extends State<FarmerRegistrationScreen> {
  final _q = TextEditingController();

  // at state level
  String? _soilType;

  String? _soilTexture;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    // TODO: call your real provider fetch method if you have one:
    // await context.read<FarmersProvider>().fetchFarmers();
  }

  @override
  Widget build(BuildContext context) {
    final farmersProvider = context.watch<FarmersProvider>();
    final all = farmersProvider.farmers; // whatever your provider exposes
    final q = _q.text.toLowerCase().trim();

    // Search by name/phone (no 'village' field in your model)
    final filtered = q.isEmpty
        ? all
        : all.where((f) {
      final name = (f.name ?? '').toLowerCase();
      final so = (f.so ?? '').toLowerCase();
      final phone = (f.phone ?? '').toLowerCase();
      // If you DO have village-like fields, add them here:
      // final resVillage = (f.residenceVillage ?? '').toLowerCase();
      // final cropVillage = (f.cropVillage ?? '').toLowerCase();
      // return name.contains(q) || phone.contains(q) || resVillage.contains(q) || cropVillage.contains(q);
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Registration'),
        automaticallyImplyLeading: false,
        leading: IconButton(
		  icon: const Icon(Icons.arrow_back),
		  tooltip: 'Back',
		  onPressed: () {
			  // back if possible
			  if (context.canPop()) {
			    context.pop();
			    return;
			  }
			  // fallback to a defined route in your GoRouter
			  context.go('/');                  // or: context.go('/farmer-network')
		     // or if you named it: context.goNamed('home');
		 },
	  ),
        actions: [
      // 1) View saved FIRST, so it’s always visible
      IconButton(
        icon: const Icon(Icons.list_alt_outlined),
        tooltip: 'View saved',
        onPressed: () => context.push('/fields/farmers/saved'),
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
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name or phone…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  //.collection('farmers')
                  .collection('farmer_registrations') // ✅ correct collection
                  .where('orgPathUids',
                          arrayContains: context.watch<AuthService>().currentUserIdOrAnon)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? const [];
                final q = _q.text.toLowerCase().trim();
                final filtered = q.isEmpty
                    ? docs
                    : docs.where((d) {
                  final m = d.data();
                  final name = (m['name'] as String? ?? '').toLowerCase();
                  final so = (m['so'] as String? ?? '').toLowerCase();
                  final phone = (m['phone'] as String? ?? '').toLowerCase();
                  return name.contains(q) || phone.contains(q);
                }).toList();

                if (filtered.isEmpty) return const _EmptyState();

                return RefreshIndicator(
                  onRefresh: () async {}, // stream auto-refreshes
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final m = doc.data();
                      final id = m['id'] as String? ?? doc.id;
                      final title = (m['name'] as String?)?.trim();
                      final sonof = (m['so'] as String?)?.trim();
                      final phone = (m['phone'] as String?)?.trim();
                      final subtitle = [phone].where((e) => (e ?? '').isNotEmpty).join(' • ');
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(title == null || title.isEmpty ? id : title),
                        subtitle: Text(subtitle.isEmpty ? '—' : subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showFarmerDetailsFromMap({
                          'id': id,
                          'name': title,
                          'so': sonof,
                          'phone': phone,
                          'residenceVillage': m['residenceVillage'],
                          'cropVillage': m['cropVillage'],
                          'cluster': m['cluster'],
                          //'territory': m['territory'],
                          'season': m['season'],
                          'hybrid': m['hybrid'],
                          'plantedArea': m['plantedArea'],
                          'waterSource': m['waterSource'],
                          'previousCrop': m['previousCrop'],
                          'sowingMethod': m['sowingMethod'],
                          'sowingSpacing': m['sowingSpacing'],
                          'soilType': m['soilType'],
                          'soilTexture': m['soilTexture'],

                        }),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text('New Registration'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FarmerRegistrationForm()),
            );
          },
        ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Farmer Details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Divider(),
                  _kv('ID', f.id ?? ''),
                  _kv('Name', f.name ?? ''),
                  _kv('So', f.so ?? ''),
                  _kv('Phone', f.phone ?? ''),
                  const Divider(),
                  _kv('Residence Village', f.residenceVillage ?? ''),
                  _kv('Crop Village', f.cropVillage ?? ''),
                  _kv('Cluster', f.cluster ?? ''),
                  //_kv('Territory', f.territory ?? ''),
                  const Divider(),
                  _kv('Season', f.season ?? ''),
                  _kv('Hybrid', f.hybrid ?? ''),
                  _kv('Planted Area', (f.plantedArea?.toString() ?? '')),
                  _kv('Water Source', f.waterSource ?? ''),
                  _kv('Sowing Method', f.sowingMethod ?? ''),
                  _kv('Sowing Spacing', f.sowingSpacing ?? ''),
                  _kv('Previous Crop', f.previousCrop ?? ''),
                  _kv('Soil Type', f.soilType ?? ''),
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
  
  void _showFarmerDetailsFromMap(Map<String, dynamic> m) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Farmer Details',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _kv('ID', (m['id'] ?? '').toString()),
            _kv('Name', (m['name'] ?? '').toString()),
            _kv('So', (m['so'] ?? '').toString()),
            _kv('Phone', (m['phone'] ?? '').toString()),
            const Divider(),
            _kv('Residence Village', (m['residenceVillage'] ?? '').toString()),
            _kv('Crop Village', (m['cropVillage'] ?? '').toString()),
            _kv('Cluster', (m['cluster'] ?? '').toString()),
            //_kv('Territory', (m['territory'] ?? '').toString()),
            const Divider(),
            _kv('Season', (m['season'] ?? '').toString()),
            _kv('Hybrid', (m['hybrid'] ?? '').toString()),
            _kv('Planted Area', (m['plantedArea']?.toString() ?? '')),
            _kv('Water Source', (m['waterSource'] ?? '').toString()),
            _kv('Sowing Method', (m['sowingMethod'] ?? '').toString()),
            _kv('Sowing Spacing', (m['sowingSpacing'] ?? '').toString()),
            _kv('Previous Crop', (m['previousCrop'] ?? '').toString()),
            _kv('Soil Type', (m['soilType'] ?? '').toString()),
            _kv('Soil Texture', (m['soilTexture'] ?? '').toString()),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(v.isEmpty ? '—' : v)),
      ],
    ),
  );
}



}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'No farmers yet. Tap “New Registration” to add one.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}


class FarmerRegistrationForm extends StatefulWidget {
  const FarmerRegistrationForm({super.key});

  @override
  State<FarmerRegistrationForm> createState() => _FarmerRegistrationFormState();
}

class _FarmerRegistrationFormState extends State<FarmerRegistrationForm> {
  final _formKey = GlobalKey<FormState>();

  // KYC
  final _nameCtrl = TextEditingController();
  final _soCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController(); // 12 digits
  final _bankNoCtrl = TextEditingController(); // account number
  //final _addressCtrl = TextEditingController(); // multi-line address

  // Villages
  final _resVillageCtrl = TextEditingController();
  final _cropVillageCtrl = TextEditingController();

  // Linking
  final _clusterCtrl = TextEditingController();
  //final _territoryCtrl = TextEditingController();

  // Agreement
  String _season = 'Kharif';
  final _hybridCtrl = TextEditingController();
  final _plantedAreaCtrl = TextEditingController();
  String? _waterSourceCtrl;
  final _previousCropCtrl = TextEditingController();

  //Hybrid check boxes and text boxes
  bool maleChecked = false;
  bool femaleChecked = false;

  final TextEditingController maleController = TextEditingController();
  final TextEditingController maleWeightController = TextEditingController();

  final TextEditingController femaleController = TextEditingController();
  final TextEditingController femaleWeightController = TextEditingController();

  // Misc
  String? _soilType;

  String? _soilTexture;

  // Sowing details
  final _sowingDateCtrl = TextEditingController();
  String _sowingType = 'Single';
  bool _dualFemale = false;
  bool _dualMale = false;

  // Sowing Method
  String _sowingMethod = 'Labour';

  // Sowing Method
  String _sowingSpacing = '24*7';

  // Photos
  final ImagePicker _picker = ImagePicker();
  XFile? _photo; // farmer photo
  XFile? _aadharPhoto; // aadhar photo
  XFile? _bankPhoto; // aadhar photo

  // Signature
  final SignatureController _sig = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _signaturePng;

  // --- Geo polygon capture ---
  final List<LatLng> _polyPoints = [];
  double _polyAreaSqm = 0;               // <-- ADD
  GoogleMapController? _mapCtrl;
  StreamSubscription<Position>? _posSub;
  bool _tracking = false;
  bool _showTrackMarkers = false;

  bool _isPickingPhoto = false;
  bool _isPickingaadhar = false;


  @override
  void dispose() {
    _posSub?.cancel();

    _mapCtrl?.dispose();
    _mapCtrl = null;

    _nameCtrl.dispose();
    _soCtrl.dispose();
    _phoneCtrl.dispose();
    _aadharCtrl.dispose();
    _bankNoCtrl.dispose();
    //_addressCtrl.dispose();

    _resVillageCtrl.dispose();
    _cropVillageCtrl.dispose();

    _clusterCtrl.dispose();
    //_territoryCtrl.dispose();

    _hybridCtrl.dispose();
    _plantedAreaCtrl.dispose();
    //_waterSourceCtrl.dispose();
    _previousCropCtrl.dispose();

    _sowingDateCtrl.dispose();

    _sig.dispose();
    maleController.dispose();
    maleWeightController.dispose();
    femaleController.dispose();
    femaleWeightController.dispose();
    super.dispose();
  }

  // ===== AppBar actions =====
  void _logout() {
    try {
      // In this app AuthService.logout() returns void (not Future)
      context.read<AuthService>().logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  void _smartBack() {
    try {
      if (context.canPop()) {
        Navigator.of(context).maybePop();
        return;
      }
    } catch (_) {}
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) root.pop();
  }

  // ===== Utilities =====
  String _buildFarmerId() {
    final v = _cropVillageCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    final n = _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    //final so = _soCtrl.text.trim().toLowerCase().replaceAll('','');
    final suffix = DateTime.now().millisecondsSinceEpoch % 1000;
    return 'FR_${v}_${n}_$suffix';
  }

// Geodesy-ish area: project lat/lng to local meters (equirectangular)
// and apply the shoelace formula. Accurate enough for fields.
  double _areaOfPolygonSqMeters(List<LatLng> pts) {
    if (pts.length < 3) return 0;

    const R = 6371000.0; // Earth radius in meters
    final lat0 = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
    final lon0 = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
    final lat0Rad = lat0 * math.pi / 180.0;

    final xy = pts.map((p) {
      final x = R * ((p.longitude - lon0) * math.pi / 180.0) * math.cos(lat0Rad);
      final y = R * ((p.latitude - lat0) * math.pi / 180.0);
      return math.Point<double>(x, y);
    }).toList();

    double sum = 0;
    for (var i = 0; i < xy.length; i++) {
      final a = xy[i];
      final b = xy[(i + 1) % xy.length];
      sum += (a.x * b.y) - (b.x * a.y);
    }
    return (sum.abs() / 2.0);
  }

  String _formatArea(double sqm) {
    if (sqm <= 0) return '0';
    final ha = sqm / 10000.0;
    final ac = sqm / 4046.8564224;
    return '${ha.toStringAsFixed(2)} ha  (${ac.toStringAsFixed(2)} ac)';
  }

  void _recomputeAreaAndMaybeFill() {
    _polyAreaSqm = _areaOfPolygonSqMeters(_polyPoints);
    // Optional: auto-fill "Planted Area" (in acres) for convenience.
    if (_polyAreaSqm > 0) {
      final hectares = _polyAreaSqm / 10000.0;
      _plantedAreaCtrl.text = hectares.toStringAsFixed(2);
    }
  }


  /// Get the next farmer suffix in a transaction: counters/farmers.next
  Future<int> _nextSuffix() async {
    final ref = FirebaseFirestore.instance.collection('counters').doc('farmers');
    return FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      int next = 1;
      if (snap.exists) {
        next = (snap.data()?['next'] as int?) ?? 1;
      }
      tx.set(ref, {'next': next + 1}, SetOptions(merge: true));
      return next;
    });
  }


  Future<void> _pickPhoto() async {
    if (_isPickingPhoto || !mounted) return;
    setState(() => _isPickingPhoto = true);
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,        // compress to reduce buffer pressure
        maxWidth: 1920,          // cap resolution
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x != null && mounted) setState(() => _photo = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _pickaadharPhoto() async {
    if (_isPickingaadhar || !mounted) return;
    setState(() => _isPickingaadhar = true);
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1920,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x != null && mounted) setState(() => _aadharPhoto = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingaadhar = false);
    }
  }

  Future<void> _bankaadharPhoto() async {
    if (_isPickingaadhar || !mounted) return;
    setState(() => _isPickingaadhar = true);
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1920,
        requestFullMetadata: false,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x != null && mounted) setState(() => _aadharPhoto = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingaadhar = false);
    }
  }

  Future<void> _exportSignature() async {
    if (_sig.isNotEmpty) {
      final data = await _sig.toPngBytes();
      if (data != null) setState(() => _signaturePng = Uint8List.fromList(data));
    } else {
      setState(() => _signaturePng = null);
    }
  }

  // ----- Geo polygon helpers -----
  Future<bool> _ensureLocationPermitted({bool forceRequest = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on Location (GPS) and try again')),
        );
      }
      await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && forceRequest) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grant location permission in App Settings')),
        );
      }
      await Geolocator.openAppSettings();
      return false;
    }
    return true;
  }

  // Great-circle distance in meters (Haversine)
  double _distMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (pi / 180.0);
    final dLng = (b.longitude - a.longitude) * (pi / 180.0);
    final la1 = a.latitude * (pi / 180.0);
    final la2 = b.latitude * (pi / 180.0);
    final h = (sin(dLat / 2) * sin(dLat / 2)) +
        (sin(dLng / 2) * sin(dLng / 2)) * cos(la1) * cos(la2);
    return 2 * r * asin(sqrt(h));
  }

  Future<void> _startTracking() async {
    if (_tracking) return;
    if (_mapCtrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is still loadingâ€¦')),
        );
      }
      return;
    }
    if (!await _ensureLocationPermitted(forceRequest: true)) return;

    // Push an initial point immediately
    try {
      final pos = await Geolocator.getCurrentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _polyPoints.add(p));
        _mapCtrl?.moveCamera(CameraUpdate.newLatLngZoom(p, 17));
      }
    } catch (_) {}

    _tracking = true;
    setState(() {});

    // High frequency stream. We accept ~any movement (>= 1 m)
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      final p = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        if (_polyPoints.isEmpty || _distMeters(_polyPoints.last, p) >= 1) {
          _polyPoints.add(p);
        }
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLng(p));
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('GPS stream error: $e')));
        setState(() => _tracking = false);
      }
    });
  }

  Future<void> _stopTracking() async {
    _tracking = false;
    await _posSub?.cancel();
    _posSub = null;
    setState(() {
    _recomputeAreaAndMaybeFill();
    });
    if (_polyPoints.length < 3 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
        Text('Need at least 3 points. Tap the map or use â€œAdd current pointâ€.'),
      ));
      return;
    }
    // Fit bounds to the collected geometry
    if (_polyPoints.length >= 2 && _mapCtrl != null) {
      double minLat = _polyPoints.first.latitude, maxLat = _polyPoints.first.latitude;
      double minLng = _polyPoints.first.longitude, maxLng = _polyPoints.first.longitude;
      for (final p in _polyPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      // Force a harmless redraw on some devices
      await _mapCtrl!.animateCamera(CameraUpdate.zoomBy(0.0));
    }
  }

  void _undoLastPoint() {
    if (_polyPoints.isNotEmpty) {
         setState(() {
             _polyPoints.removeLast();
             _recomputeAreaAndMaybeFill();
           });
    }
  }


  void _clearPolygon() {
    setState(() {
      _polyPoints.clear();
      _recomputeAreaAndMaybeFill();
    });
  }


  // ===== Submit =====
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await _exportSignature();

    if (_sowingType == 'Dual' && !_dualFemale && !_dualMale) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Female and/or Male for Dual sowing')),
      );
      return;
    }

    final id = _buildFarmerId();
    final area = double.tryParse(_plantedAreaCtrl.text.trim());
    if (area == null || area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Value for Planted Area')),
      );
      return;
    }

    final dualParts = <String>[];
    if (_sowingType == 'Dual') {
      if (_dualFemale) dualParts.add('Female');
      if (_dualMale) dualParts.add('Male');
    }
    final dualText = dualParts.isEmpty ? '' : ' (${dualParts.join('+')})';

    final polyJson =
    _polyPoints.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList();

    // Keep compatibility with current Farmer model by appending into 'previousCrop'
    final prevWithExtras = [
      _previousCropCtrl.text.trim(),
      if (_aadharCtrl.text.trim().isNotEmpty)
        'aadhar:${_aadharCtrl.text.trim()}',
      if (_bankNoCtrl.text.trim().isNotEmpty)
        'BankNo:${_bankNoCtrl.text.trim()}',
      //if (_addressCtrl.text.trim().isNotEmpty)
        //'Address:${_addressCtrl.text.trim()}',
      if (_sowingDateCtrl.text.trim().isNotEmpty)
        'SowingTime:${_sowingDateCtrl.text.trim()}',
      'SowingType:${_sowingType}$dualText',
      if (_aadharPhoto != null) 'aadharPhoto:${_aadharPhoto!.path}',
      if (_polyPoints.isNotEmpty) 'GeoPoly:${jsonEncode(polyJson)}',
    ].where((s) => s.isNotEmpty).join(' | ');

    final farmer = Farmer(
      id: id,
      name: _nameCtrl.text.trim(),
      so: _soCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      residenceVillage: _resVillageCtrl.text.trim(),
      cropVillage: _cropVillageCtrl.text.trim(),
      cluster: _clusterCtrl.text.trim(),
      //territory: _territoryCtrl.text.trim(),
      season: _season,
      hybrid: _hybridCtrl.text.trim(),
      plantedArea: area,
      waterSource: _waterSourceCtrl,
      previousCrop: prevWithExtras, // includes extras for now
      soilType: _soilType,
      soilTexture: _soilTexture,
      sowingMethod: _sowingMethod,
      sowingSpacing: _sowingSpacing,
      photoPath: _photo?.path,
      signaturePng: _signaturePng == null ? null : base64Encode(_signaturePng!),
	    createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      createdAt: Timestamp.now(),
    );

    // --- WRITE to Firestore so the StreamBuilder can see it ---
    // placeholder until you wire real auth; keeps build green
    final auth = context.read<AuthService>();
    final uid  = auth.currentUserIdOrAnon;
    final org  = auth.orgPathUidList;

    final data = {
      'id': id,
      'name': _nameCtrl.text.trim(),
      'so': _soCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'residenceVillage': _resVillageCtrl.text.trim(),
      'cropVillage': _cropVillageCtrl.text.trim(),
      'cluster': _clusterCtrl.text.trim(),
      //'territory': _territoryCtrl.text.trim(),
      'season': _season,
      'hybrid': _hybridCtrl.text.trim(),
      'plantedArea': area,
      'waterSource': _waterSourceCtrl,
      'previousCrop': prevWithExtras,
      'soilType': _soilType,
      'soilTexture': _soilTexture,
      'photoPath': _photo?.path,
      'signaturePng': _signaturePng == null ? null : base64Encode(_signaturePng!),      
	     'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ⬇️ REQUIRED BY RULES
    data['createdBy']   = data['createdBy'] ?? uid;
    data['orgPathUids'] = (data['orgPathUids'] as List?) ?? (org.isNotEmpty ? org : [uid]);

    await FirebaseFirestore.instance
        //.collection('farmers')
        .collection('farmer_registrations')    // ✅ correct collection
        .doc(id) // your FR_xxx id
        .set(data, SetOptions(merge: true));


    // NEW: push to provider
    context.read<FarmersProvider>().addFarmer(farmer);

    if (!mounted) return;

    // Pop all intermediate routes until the root FarmerRegistrationScreen
    Navigator.of(context).popUntil((route) => route.isFirst);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Farmer created: $id')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Registration'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _smartBack,
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('KYC'),
                _tf('Farmer Full Name', _nameCtrl, required: true),
                _tf('S/o', _soCtrl, required: true),
                _tf('Phone', _phoneCtrl,
                    type: TextInputType.phone, required: true),

                // aadhar number
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextFormField(
                    controller: _aadharCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'aadhar Number',
                      hintText: '12-digit ID',
                      isDense: true,
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Required';
                      if (t.length != 12) return 'Enter 12 digits';
                      return null;
                    },
                  ),
                ),

                // aadhar photo
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isPickingaadhar ? null : _pickaadharPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('aadhar Photo'),
                    ),
                    const SizedBox(width: 12),
                    if (_aadharPhoto != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_aadharPhoto!.path),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),

                // Bank account
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextFormField(
                    controller: _bankNoCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(20),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Bank Account Number',
                      hintText: 'e.g. 10â€“18 digits',
                      isDense: true,
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Required';
                      if (t.length < 9) return 'Too short';
                      return null;
                    },
                  ),
                ),

                // bank photo
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isPickingaadhar ? null : _pickaadharPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Bank Passbook Photo'),
                    ),
                    const SizedBox(width: 12),
                    if (_bankPhoto != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_bankPhoto!.path),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),

                /*const SizedBox(height: 8),
                _section('Address'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextFormField(
                    controller: _addressCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Address',
                      hintText:
                      'Door No / Street / Village / Mandal / District / Pincode',
                      isDense: true,
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                ),*/

                const SizedBox(height: 8),
                _section('Villages'),
                //_tf('Residence Village', _resVillageCtrl, required: true),
                //_tf('Crop Village', _cropVillageCtrl, required: true),
                TextFormField(
                  controller: _resVillageCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.home_work_outlined, color: Colors.grey),
                    labelText: 'Residence Village',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _cropVillageCtrl,
                  decoration: InputDecoration(
                    labelText: 'Crop Village',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/icons/maize_single.png', // adjust path as needed
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),


                const SizedBox(height: 8),
                _section('Field Boundary (Geo-polygon)'),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(17.3850, 78.4867), // fallback
                        zoom: 14,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: false,

                      // Markers for each point
                      markers: {
                        if (_showTrackMarkers && _polyPoints.isNotEmpty)
                          Marker(markerId: const MarkerId('start'), position: _polyPoints.first),
                        if (_showTrackMarkers && _polyPoints.length > 1)
                          Marker(markerId: const MarkerId('end'), position: _polyPoints.last),
                      },

                      polygons: {
                        if (_polyPoints.length >= 3)
                          Polygon(
                            polygonId: const PolygonId('field'),
                            points: _polyPoints,
                            strokeWidth: 3,
                            strokeColor: Colors.green,
                            fillColor: Colors.green.withOpacity(0.2),
                          ),
                      },
                      polylines: {
                        if (_polyPoints.length >= 2)
                          Polyline(
                            polylineId: const PolylineId('trace'),
                            points: _polyPoints,
                            width: 3,
                            color: Colors.blue,
                          ),
                      },
                      onMapCreated: (c) async {
                        _mapCtrl = c;
                        if (await _ensureLocationPermitted(
                            forceRequest: false)) {
                          try {
                            final pos =
                            await Geolocator.getCurrentPosition();
                            final here =
                            LatLng(pos.latitude, pos.longitude);
                            _mapCtrl?.moveCamera(
                              CameraUpdate.newLatLngZoom(here, 17),
                            );
                          } catch (_) {}
                        }
                      },

                      // Tap-to-add (always add a vertex)
                      onTap: (p) => setState(() {
                        _polyPoints.add(p);
                        _recomputeAreaAndMaybeFill();
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _tracking ? null : _startTracking,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _tracking ? _stopTracking : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Finish'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _polyPoints.isEmpty ? null : _undoLastPoint,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _polyPoints.isEmpty ? null : _clearPolygon,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (!await _ensureLocationPermitted(
                            forceRequest: true)) return;
                        try {
                          final pos =
                          await Geolocator.getCurrentPosition();
                          final p =
                          LatLng(pos.latitude, pos.longitude);
                          if (mounted) {
                            // ALWAYS add current point (no distance guard)
                            //setState(() => _polyPoints.add(p));
                            onPressed: () async {
                              try {
                                final pos = await Geolocator.getCurrentPosition();
                                setState(() {
                                  _polyPoints.add(LatLng(pos.latitude, pos.longitude));
                                  _recomputeAreaAndMaybeFill();
                                });
                              } catch (_) {}
                            };
                        _mapCtrl?.animateCamera(
                                CameraUpdate.newLatLng(p));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Could not fetch location: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Add current point'),
                    ),
                    Chip(label: Text('Points: ${_polyPoints.length}')),
                    const SizedBox(width: 12),
                    Chip(
                          label: Text('Area: ${_formatArea(_polyAreaSqm)}'),
                    ),
                    if (_tracking) const Chip(label: Text('Recording')),
                  ],
                ),

                const SizedBox(height: 8),
                _section('Linking'),
                _tf('Cluster', _clusterCtrl, required: true),
                //_tf('Territory', _territoryCtrl, required: true),

                const SizedBox(height: 8),
                _section('Agreement'),
                _dropdown(
                  label: 'Season',
                  value: _season,
                  items: const ['Kharif', 'Rabi', 'Summer'],
                  onChanged: (v) => setState(() => _season = v ?? _season),
                ),
                _tf('Hybrid (required)', _hybridCtrl, required: true),
                const SizedBox(height: 12),
                
                //_displayOnly('Soil Type', _soilType),
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
                        (e) => DropdownMenuItem<String>(value: e, child: Text(e)))
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


                //_tf('Water Source (required)', _waterSourceCtrl,
                    //required: true),
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
                _tf('Previous Crop (required)', _previousCropCtrl,
                    required: true),

                const SizedBox(height: 12),
                _section('Sowing Details'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sowingDateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Sowing Date',
                          //hintText: 'e.g. 8:30 AM or Morning',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                          //isDense: true,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sowingType,
                        decoration: const InputDecoration(
                          labelText: 'Sowing Type',
                          //prefixIcon: Icon(Icons.agriculture_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
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
                        onChanged: (v) => setState(() => _sowingType = v ?? 'Single'),
                      ),
                    ),
                  ],
                ),
                if (_sowingType == 'Dual') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Female'),
                          value: _dualFemale,
                          onChanged: (v) =>
                              setState(() => _dualFemale = v ?? false),
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
                          onChanged: (v) =>
                              setState(() => _dualMale = v ?? false),
                        ),
                      ),
                    ],
                  ),
                ],

                //Sowing Method
                const SizedBox(height: 8),
                _section('Sowing Method'),
                _dropdown(
                  label: 'Sowing Method',
                  value: _sowingMethod,
                  items: const ['Labour', 'Push Planter', 'Tractor Planter'],
                  onChanged: (v) => setState(() => _sowingMethod = v ?? _sowingMethod),
                ),

                //Sowing Spacing
                const SizedBox(height: 8),
                _section('Sowing Spacing(inches)'),
                _dropdown(
                  label: 'Sowing Spacing(inches)',
                  value: _sowingSpacing,
                  items: const ['24*7', '22*5', '22*7'],
                  onChanged: (v) => setState(() => _sowingSpacing = v ?? _sowingSpacing),
                ),

                const SizedBox(height: 14),
                _section('Attachments'),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isPickingPhoto ? null : _pickPhoto,
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
                _section('Signature'),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Signature(
                    controller: _sig,
                    backgroundColor: Colors.white,
                  ),
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
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check),
                      label: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Small UI helpers =====
  Widget _tf(String label, TextEditingController c,
      {TextInputType? type, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: ' ',
          isDense: true,
        ).copyWith(labelText: label),
        validator: (v) =>
        required && (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          isDense: true,
        ),
        items:
        items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _displayOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          isDense: true,
        ),
        child: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}