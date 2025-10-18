import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/audit_meta.dart';
import '../../core/services/auth_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';         // if _ymd is not already available

import 'activity_schedule_details_screen.dart';


// Single source of truth for the dropdown value: "FR_..." or "FN_..."
String? _selectedFarmerOrFieldId;


const String kActivityScheduleCollection = 'activity_schedule';

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _buildDocId({
  required DateTime date,
  required String createdBy,
  String? farmerId,
}) =>
    '${(farmerId ?? createdBy)}_${_ymd(date)}';

// Turn Firestore values into JSON-encodable values.
dynamic _encodable(dynamic v) {
  if (v is Timestamp) return v.toDate().toIso8601String();       // "2025-10-05T00:00:00.000"
  if (v is DateTime) return v.toIso8601String();
  if (v is List) return v.map(_encodable).toList();
  if (v is Map) {
    return (v as Map).map((k, val) => MapEntry(k.toString(), _encodable(val)));
  }
  return v;                                                       // numbers, strings, bools…
}



class ActivityScheduleScreen extends StatefulWidget {
  const ActivityScheduleScreen({super.key});

  @override
  State<ActivityScheduleScreen> createState() => _ActivityScheduleScreenState();

}

/* ===========================
   MODELS
   =========================== */

class ActivityItem {
  final String stageLabel;
  final String activityWithSuppliers;
  final String supplier;

  DateTime? scheduledDate;
  DateTime? completedDate;

  // New: keep remarks in a controller (so the UI and save use the same source)
  final TextEditingController remarksCtrl;

  ActivityItem({
    required this.stageLabel,
    required this.activityWithSuppliers,
    required this.supplier,
    this.scheduledDate,
    this.completedDate,
    TextEditingController? remarksCtrl,
  }) : remarksCtrl = remarksCtrl ?? TextEditingController();
}

class OperationItem {
  // Use String so 'O1', 'O2' etc compile
  final String opNo;
  final String operation;

  /// Canonical field
  final String recommendedTiming;

  final String responsible;

  DateTime? scheduledDate;
  DateTime? completedDate;

  final TextEditingController remarksCtrl;

  OperationItem({
    required this.opNo,
    required this.operation,

    // Accept BOTH names so existing seeds using `recommended:` still compile
    String? recommended,
    String? recommendedTiming,

    required this.responsible,
    this.scheduledDate,
    this.completedDate,
    TextEditingController? remarksCtrl,
  })  : recommendedTiming = recommendedTiming ?? recommended ?? '',
        remarksCtrl = remarksCtrl ?? TextEditingController();

  // Back-compat getter so reads of `op.recommended` continue to work
  String get recommended => recommendedTiming;
}


/* ===========================
   STATE
   =========================== */

class _ActivityScheduleScreenState extends State<ActivityScheduleScreen>
    with SingleTickerProviderStateMixin {
  // Fake farmer selection; wire to your provider later.
  String? _selectedFarmer;

  // in your State
  String? _lastSavedDocId;

  // Sample seeds — replace with your real rows (keep the fields)
  final List<ActivityItem> _activityItems = [
    ActivityItem(
      stageLabel: 'Before sowing',
      activityWithSuppliers: '1.5 Bag DAP + 0.5 kg Zinc Sulphate OR 3 Bags SSP',
      supplier: 'Farmer',
    ),
    ActivityItem(
      stageLabel: '1–2 days',
      activityWithSuppliers: 'Atrazine 0.5 kg or Atrazine 1 kg',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '12–14 days',
      activityWithSuppliers: 'Spolit / Proclaim (Emamectin Benzoate) 100 g',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '15 days',
      activityWithSuppliers: 'Neem Urea 0.5 l + Neem oil 200:15',
      supplier: 'Farmer',
    ),
    ActivityItem(
      stageLabel: '18–20 days',
      activityWithSuppliers: 'Gunther 500 ml + Chelamin Zinc 100 gm',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '20–25 days',
      activityWithSuppliers:  'Saaf 500 gm + 1 kg of 19:19:19 + 0.5 kg Agronomin Max',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '25–30 days',
      activityWithSuppliers:  '1.5 Bag of 14:35:14 + 0.5 Bag of Urea OR 2 Bags of 28:28',
      supplier: 'Farmer',
    ),
    ActivityItem(
      stageLabel: '28–33 days',
      activityWithSuppliers:  'Delegate Drops 100 ml + Macarena 500 ml',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '33–35 days',
      activityWithSuppliers:  '1.5 Bag of 14:35:14 + 0.5 Bag of Urea OR 2 Bags of 28:28',
      supplier: 'Farmer',
    ),
    ActivityItem(
      stageLabel: '35-40 days',
      activityWithSuppliers:  'Antracol OR Avathar 500 gm',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '40-45 days',
      activityWithSuppliers:  'Granules 4 kg',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '45–50 days',
      activityWithSuppliers:  'Nativo 150 gm OR Avancer Glow 600 gm',
      supplier: 'Company',
    ),
    ActivityItem(
      stageLabel: '50–55 days',
      activityWithSuppliers:  '1 Bag of Ammonium Sulphate + 1 Bag of Potash',
      supplier: 'Farmer',
    ),
    ActivityItem(
      stageLabel: '75–80 days',
      activityWithSuppliers:  'Blitox 500 gm + 1 kg of 13-0-45',
      supplier: 'Company',
    ),
  ];

  final List<OperationItem> _operationItems = [
    OperationItem(opNo: 'O1', operation: 'Sowing', recommended: 'Day 0', responsible: 'Farmer'),
    OperationItem(opNo: 'O2', operation: 'Weeding (1st)',   recommended: '~15 days',      responsible: 'Farmer'),
    OperationItem(opNo: 'O3', operation: 'Inter-cultivation',            recommended: '~20–25 days',    responsible: 'Farmer'),
    OperationItem(opNo: 'O4', operation: 'Fertiliser Application (general)',           recommended: 'As per package of practice (POP)',       responsible: 'Company'),
    OperationItem(opNo: 'O5', operation: 'Spraying (general)',       recommended: 'Preventive/protective as needed',    responsible: 'Company'),
    OperationItem(opNo: 'O6', operation: 'Irrigation 1',   recommended: 'After ~10 days',      responsible: 'Farmer'),
    OperationItem(opNo: 'O7', operation: 'Irrigation 2',            recommended: 'After ~30 days',    responsible: 'Farmer'),
    OperationItem(opNo: 'O8', operation: 'Irrigation 3',           recommended: 'After ~60 days',       responsible: 'Farmer'),
    OperationItem(opNo: '09', operation: 'Detaziling',       recommended: 'After 55 days',    responsible: 'Company'),
    OperationItem(opNo: '10', operation: 'Harvesting',       recommended: '120 days',    responsible: 'Farmer'),
  ];


  // Add these two lines:
  List<ActivityItem> get _activities => _activityItems;
  List<OperationItem> get _operations => _operationItems;

  /*--------------------------------------------Headers--------------------------------------------*/
  Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

// defensively read fields because your model names changed a few times
  String _txt(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _activityRowToMap(ActivityItem it, int index) => {
    'sno'        : index + 1,
    'cropStage'  : it.stageLabel,
    'activity'   : it.activityWithSuppliers,
    'supplier'   : it.supplier,
    'scheduled'  : it.scheduledDate == null ? null : Timestamp.fromDate(it.scheduledDate!),
    'completed'  : it.completedDate == null ? null : Timestamp.fromDate(it.completedDate!),
    'remarks'    : it.remarksCtrl.text.trim(),
  };

  Map<String, dynamic> _operationRowToMap(OperationItem it, int index) => {
    'sno'                : index + 1,
    'opNo'               : it.opNo,
    'operation'          : it.operation,
    'recommendedTiming'  : it.recommendedTiming,
    'responsible'        : it.responsible,
    'scheduled'          : it.scheduledDate == null ? null : Timestamp.fromDate(it.scheduledDate!),
    'completed'          : it.completedDate == null ? null : Timestamp.fromDate(it.completedDate!),
    'remarks'            : it.remarksCtrl.text.trim(),
  };

  @override
  void dispose() {
    for (final it in _activityItems) it.remarksCtrl.dispose();
    for (final it in _operationItems) it.remarksCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFarmerIdItems();
  }



  bool _saving = false;

  Future<List<String>> _orgPathUidsFor(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? const {};
    final List path = (data['orgPathUids'] ?? [uid]) as List;

    return path.map((e) => e.toString()).toList();
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


  Future<void> _saveToFirestore() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Auth & org path
      final authService = context.read<AuthService>();
      final createdBy   = authService.currentUser?.uid ?? authService.currentUserId ?? 'anon';
      final orgPathUids = await _orgPathUidsFor(createdBy);

      // MUST come from the Farmer / Field ID dropdown (FR_* or FN_* exactly as chosen)
      final String farmerId = (_selectedFarmerOrFieldId ?? '').trim();
      if (farmerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pick a Farmer / Field ID')),
          );
        }
        setState(() => _saving = false);
        return;
      }



      // If you already keep a page-level date, use that; else now()
      final DateTime pageDate = DateTime.now();

      // Build rows from in-memory tables
      final List<Map<String, dynamic>> activityRows = _activities
          .asMap()
          .entries
          .map((e) => _activityRowToMap(e.value, e.key))
          .toList();

      final List<Map<String, dynamic>> operationRows = _operations
          .asMap()
          .entries
          .map((e) => _operationRowToMap(e.value, e.key))
          .toList();

      // Audit meta
      final Map<String, dynamic> audit = await AuditMeta.build(authService);

      // ---- Payload (kept as you had it) ----
      final payload = <String, dynamic>{
        'date'            : Timestamp.fromDate(DateTime(pageDate.year, pageDate.month, pageDate.day)),
        'dateYMD'         : _ymd(pageDate),
        'farmerOrFieldId' : farmerId,
        'createdAt'       : FieldValue.serverTimestamp(),
        'updatedAt'       : FieldValue.serverTimestamp(),
        'createdBy'       : createdBy,
        'orgPathUids'     : orgPathUids,
        'activities'      : activityRows,
        'operations'      : operationRows,
        ...audit,
      };

      // deterministic doc id: exactly what the details screen expects
      final String docId = '${farmerId}_${_ymd(pageDate)}';

      final col = FirebaseFirestore.instance.collection(kActivityScheduleCollection);

      debugPrint('[SAVE] docId=$docId farmerOrFieldId=$farmerId '
          'ops=${operationRows.length} acts=${activityRows.length}');

      await col.doc(docId).set(payload, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ActivityScheduleDetailsScreen(docId: docId),
      ));

      // inside _saveToFirestore(), after the write and before push/snackbar:
      setState(() => _lastSavedDocId = docId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity schedule saved')),
      );
    } catch (e, st) {
      debugPrint('Activity schedule save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }



  /* ---------- styles & helpers ---------- */

  final _tableBorder = TableBorder(
    horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1),
    verticalInside: BorderSide(color: Colors.grey.shade300, width: 1),
    top: BorderSide(color: Colors.grey.shade300),
    left: BorderSide(color: Colors.grey.shade300),
    right: BorderSide(color: Colors.grey.shade300),
    bottom: BorderSide(color: Colors.grey.shade300),
  );

  final _headRowDecoration = const BoxDecoration(color: Color(0xFFF3F4F6));

  Decoration _bodyRowDecoration(int index) => BoxDecoration(
    color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
  );

  int _daysUpperFromText(String? text) {
    if (text == null) return 0;
    final s = text.toLowerCase().trim();

    // Range like "10–12 days" or "10-12 days"
    final reRange = RegExp(r'(\d+)\s*[–-]\s*(\d+)');
    final mRange = reRange.firstMatch(s);
    if (mRange != null) {
      return int.tryParse(mRange.group(2) ?? '0') ?? 0; // upper bound
    }

    // Weeks like "2 weeks" / "3 week"
    final reWeeks = RegExp(r'(\d+)\s*(week|weeks|w)\b');
    final mWeeks = reWeeks.firstMatch(s);
    if (mWeeks != null) {
      final w = int.tryParse(mWeeks.group(1) ?? '0') ?? 0;
      return w * 7;
    }

    // Days like "~15 days", "15 day", "15d"
    final reDays = RegExp(r'~?\s*(\d+)\s*(day|days|d)\b');
    final mDays = reDays.firstMatch(s);
    if (mDays != null) {
      return int.tryParse(mDays.group(1) ?? '0') ?? 0;
    }

    // Zero-offset keywords
    if (s.contains('at sowing') || s.contains('immediate') || s.contains('same day')) {
      return 0;
    }

    return 0;
  }

  void _autoFillOperationsFromFirst(DateTime base) {
    // Row 0 is the “Before sowing” baseline; keep what user picked
    if (_operationItems.isEmpty) return;

    for (int i = 1; i < _operationItems.length; i++) {
      final op = _operationItems[i];
      final off = _daysUpperFromText(op.recommendedTiming); // uses canonical field
      // (or keep `op.recommended` thanks to the getter in #1)
      op.scheduledDate = base.add(Duration(days: off));
    }
    setState(() {}); // refresh the UI
  }


  Widget _th(String text) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );

  Widget _cellText(String text) =>
      Padding(padding: const EdgeInsets.all(8), child: Text(text));

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _datePill(DateTime? value, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.event, size: 18),
        onPressed: onTap,
        label: Text(value == null ? 'Pick' : _ymd(value)),
      ),
    );
  }

  Future<void> _pickDateAct(ActivityItem item,
      {required bool isScheduled, required int rowIndex}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isScheduled ? (item.scheduledDate ?? now) : (item.completedDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;

    setState(() {
      if (isScheduled) {
        item.scheduledDate = picked;
        // auto-fill subsequent rows based on upper bound of stage
        if (rowIndex == 0 && _activityItems.isNotEmpty) {
          _activityItems[0].scheduledDate = picked;
          DateTime base = picked;
          for (int i = 1; i < _activityItems.length; i++) {
            final offset = _daysUpperFromText(_activityItems[i].stageLabel);
            _activityItems[i].scheduledDate = base.add(Duration(days: offset));
          }
        }
      } else {
        item.completedDate = picked;
      }
    });
  }

  Future<void> _pickDateOp(
      OperationItem item, {
        required bool isScheduled,
        required int rowIndex,
      }) async {
    final now = DateTime.now();
    final init = item.scheduledDate ?? item.completedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;

    setState(() {
      if (isScheduled) {
        item.scheduledDate = picked;
      } else {
        item.completedDate = picked;
      }
    });

    // If user set the scheduled date on the first row ⇒ auto-fill the rest
    if (isScheduled && rowIndex == 0) {
      _autoFillOperationsFromFirst(picked);
    }
  }

  /* ---------- UI ---------- */

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity Schedule'),
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
              onPressed: () {
                final auth = context.read<AuthService>();
                final createdBy = auth.currentUser?.uid ?? auth.currentUserId ?? 'anon';

                // use the same farmer selection and date you used when saving
                final String? farmerId = (_selectedFarmer?.trim().isEmpty ?? true)
                    ? null
                    : _selectedFarmer!.trim();
                final DateTime date = DateTime.now(); // or your page date

                final docId = _buildDocId(date: date, createdBy: createdBy, farmerId: farmerId);
                context.goNamed('fi.activity.schedule.detail', pathParameters: {'docId': docId});
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
          bottom: const TabBar(
            tabs: [Tab(text: 'Crop Operation'), Tab(text: 'Crop Protection')],
            labelColor: Colors.white,            // <-- visible
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildActivityTab(),
            _buildOperationTab(),
          ],
        ),
      ),
    );
  }

  Widget _farmerDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFarmerOrFieldId,
      isExpanded: true,
      hint: const Text('Farmer / Field ID'),
      items: _farmerIdItems,
      onChanged: (v) => setState(() => _selectedFarmerOrFieldId = v),
      decoration: const InputDecoration(
        labelText: 'Farmer / Field ID',
        prefixIcon: Icon(Icons.badge_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _farmerDropdown(),
          const SizedBox(height: 16),
          const Text(
            'Crop Activity Schedule (with suppliers)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 860),
              child: Table(
                border: _tableBorder,
                columnWidths: const {
                  0: FixedColumnWidth(56),  // S.No
                  1: FlexColumnWidth(1.2),  // Stage
                  2: FlexColumnWidth(2.0),  // Activity / Inputs
                  3: FlexColumnWidth(1.5),  // Supplier
                  4: FixedColumnWidth(160), // Scheduled
                  5: FixedColumnWidth(160), // Completed
                  6: FlexColumnWidth(2.0),  // Remarks
                },
                children: [
                  // ---- header (7 cells) ----
                  TableRow(
                    decoration: _headRowDecoration,
                    children: [
                      _th('S.No'),
                      _th('Crop Stage'),
                      _th('Activity / Inputs'),
                      _th('Supplier'),
                      _th('Scheduled date'),
                      _th('Completed Date'),
                      _th('Remarks / Reason if not completed'),
                    ],
                  ),
                  // rows
                  ...List<TableRow>.generate(_activityItems.length, (rIdx) {
                    final act = _activityItems[rIdx];
                    return TableRow(
                      decoration: _bodyRowDecoration(rIdx),
                      children: [
                        _cellText('${rIdx + 1}'),
                        _cellText(act.stageLabel),
                        _cellText(act.activityWithSuppliers),
                        _cellText(act.supplier ?? '—'),
                        _datePill(
                          act.scheduledDate,
                          onTap: () => _pickDateAct(act, isScheduled: true, rowIndex: rIdx),
                        ),
                        _datePill(
                          act.completedDate,
                          onTap: () => _pickDateAct(act, isScheduled: false, rowIndex: rIdx),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: act.remarksCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: 'Remarks…',
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
                onPressed: _saving ? null : _saveToFirestore,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outlined),
                label: const Text('Submit'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Submitted (stub)')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _farmerDropdown(),
          const SizedBox(height: 16),
          const Text(
            'Crop Operation Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 860),
              child: Table(
                border: _tableBorder,
                columnWidths: const {
                  0: FixedColumnWidth(96),  // Operation No.
                  1: FlexColumnWidth(1.8),  // Operation
                  2: FlexColumnWidth(1.4),  // Recommended
                  3: FlexColumnWidth(1.4),  // Responsible
                  4: FixedColumnWidth(160), // Scheduled
                  5: FixedColumnWidth(160), // Completed
                  6: FlexColumnWidth(2.0),  // Remarks
                },
                children: [
                  TableRow(
                    decoration: _headRowDecoration,
                    children: [
                      _th('Operation No.'),
                      _th('Operation'),
                      _th('Recommended Timing'),
                      _th('Responsible'),
                      _th('Scheduled date'),
                      _th('Completed Date'),
                      _th('Remarks / Reason if not completed'),
                    ],
                  ),
                  ...List<TableRow>.generate(_operationItems.length, (rIdx) {
                    final op = _operationItems[rIdx];
                    return TableRow(
                      decoration: _bodyRowDecoration(rIdx),
                      children: [
                        _cellText(op.opNo),
                        _cellText(op.operation),
                        _cellText(op.recommended),
                        _cellText(op.responsible ?? '—'),

                        //Scheduled Date
                        _datePill(
                          op.scheduledDate,
                          onTap: () => _pickDateOp(
                            op,
                            isScheduled: true,
                            rowIndex: rIdx, // <-- IMPORTANT
                          ),
                        ),

                        // Completed date
                        _datePill(
                          op.completedDate,
                          onTap: () => _pickDateOp(
                            op,
                            isScheduled: false,
                            rowIndex: rIdx, // <-- for consistency
                          ),
                        ),

                        // Remarks
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: op.remarksCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: 'Remarks…',
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved (stub)')),
                  );
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outlined),
                label: const Text('Submit'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Submitted (stub)')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
