import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/top_app_bar.dart';
import '../../core/models/diagnosis.dart';
import '../../core/services/diagnostics_provider.dart';
import '../../core/services/auth_service.dart';


class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = context.watch<DiagnosticsProvider>().items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Diagnostics'),
        automaticallyImplyLeading: false, // show our own back even if a Drawer exists
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _smartBack(context),
        ),
        actions: [
            // 1) View saved FIRST, so it’s always visible
            /*IconButton(
              icon: const Icon(Icons.list_alt_outlined),
              tooltip: 'View saved',
              onPressed: () => context.push('/fields/diagnostics/saved'),
            ),*/

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
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.biotech),
        label: const Text('New Diagnosis'),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1200),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _DiagnosticsTable(rows: rows),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => const _CreateDiagnosisSheet(),
    );
  }

  void _smartBack(BuildContext context) {
    // Close drawer if it’s open
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // closes drawer
      return;
    }

    if (context.canPop()) {
      context.pop();              // normal back
      return;
    }
    context.go('/');              // <- your home/dashboard path
    // or: context.goNamed('home');
  }


  void _logout(BuildContext context) {
    try {
      context.read<AuthService>().logout();
    } catch (_) {}
    if (!context.mounted) return;
    context.go('/welcome');
  }


}

class _DiagnosticsTable extends StatelessWidget {
  final List<DiagnosisEntry> rows;
  const _DiagnosticsTable({required this.rows});

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowHeight: 52,
      dataRowMaxHeight: 90,
      columns: const [
        DataColumn(label: _Th('Date')),
        DataColumn(label: _Th('Farmer / Field ID')),
        DataColumn(label: _Th('Category')),
        DataColumn(label: _Th('Description')),
        DataColumn(label: _Th('Photos')),
        DataColumn(label: _Th('Predicted Issue')),
        DataColumn(label: _Th('Confidence (%)')),
        DataColumn(label: _Th('Recommended Action')),
        DataColumn(label: _Th('Severity')),
        DataColumn(label: _Th('Remarks')),
      ],
      rows: rows.map((r) {
        return DataRow(cells: [
          DataCell(Text(_fmtDate(r.date))),
          DataCell(Text(r.farmerOrFieldId)),
          DataCell(Text(r.category)),
          DataCell(Text(r.description)),
          DataCell(_Thumbs(paths: r.imagePaths)),
          DataCell(Text(r.predictedIssue)),
          DataCell(Text('${r.confidence}')),
          DataCell(Text(r.recommendedAction)),
          DataCell(Text(r.severity)),
          DataCell(Text(r.remarks)),
        ]);
      }).toList(),
    );
  }
}

class _Thumbs extends StatelessWidget {
  final List<String> paths;
  const _Thumbs({required this.paths});

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const Text('—');
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final p = paths[i];
          return InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(child: Image.file(File(p), fit: BoxFit.contain)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(p), width: 64, height: 64, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700));
  }
}

class _CreateDiagnosisSheet extends StatefulWidget {
  const _CreateDiagnosisSheet();

  @override
  State<_CreateDiagnosisSheet> createState() => _CreateDiagnosisSheetState();
}

class _CreateDiagnosisSheetState extends State<_CreateDiagnosisSheet> {
  final _form = GlobalKey<FormState>();

  DateTime _date = DateTime.now();
  final _farmerId = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'Disease';
  final _severity = TextEditingController(text: '3 (≈25%)');
  final _remarks = TextEditingController();

  String _predicted = '';
  int _confidence = 0;
  final _action = TextEditingController();

  final List<String> _images = [];
  final _picker = ImagePicker();

  final _categories = const ['Disease', 'Pest', 'Nutrient', 'Weed', 'Other'];

  @override
  void dispose() {
    _farmerId.dispose();
    _desc.dispose();
    _severity.dispose();
    _remarks.dispose();
    _action.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- Mock AI: quick rules on text to prefill fields ----
  void _runMockAI() {
    final t = _desc.text.toLowerCase();
    String issue = 'Unknown';
    int conf = 65;
    String rec = 'Observe and re-check in 2–3 days.';

    if (t.contains('lesion') || t.contains('blight') || t.contains('spot')) {
      issue = 'Leaf blight';
      conf = 90;
      rec = 'Spray Mancozeb @2 g/L; avoid late evening irrigation.';
    } else if (t.contains('miner') || t.contains('tunnel')) {
      issue = 'Leaf miner';
      conf = 88;
      rec = 'Spray Emamectin 0.4 g/L; monitor after 72h.';
    } else if (t.contains('yellow') || t.contains('pale') || t.contains('stunted')) {
      issue = 'Nitrogen deficiency';
      conf = 84;
      rec = 'Foliar urea 2%; top-dress as per recommendation.';
    } else if (t.contains('weed')) {
      issue = 'Weed pressure';
      conf = 80;
      rec = 'Apply recommended post-emergent herbicide; manual weeding if needed.';
    } else if (t.contains('wilt') || t.contains('droop')) {
      issue = 'Water stress';
      conf = 82;
      rec = 'Irrigate; mulch between rows; check drainage.';
    }

    setState(() {
      _predicted = issue;
      _confidence = conf;
      _action.text = rec;
    });
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await _picker.pickImage(source: src, imageQuality: 75);
    if (x != null) setState(() => _images.add(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Diagnosis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _DateTile(
                      label: 'Date',
                      value: _fmtDate(_date),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context, initialDate: _date,
                            firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (d != null) setState(() => _date = d);
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _farmerId,
                      decoration: const InputDecoration(labelText: 'Farmer / Field ID'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    )),
                  ],
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Symptoms / Description (AI reads this)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _pickImage(ImageSource.camera),
                      label: const Text('Camera'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      label: const Text('Gallery'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      onPressed: _runMockAI,
                      label: const Text('Run AI (mock)'),
                    ),
                  ],
                ),

                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(_images[i]),
                            width: 72, height: 72, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(text: _predicted),
                      decoration: const InputDecoration(labelText: 'Predicted Issue (AI)'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(text: _confidence == 0 ? '' : '$_confidence'),
                      decoration: const InputDecoration(labelText: 'Confidence (%)'),
                    )),
                  ],
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _action,
                  decoration: const InputDecoration(labelText: 'Recommended Action'),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      controller: _severity,
                      decoration: const InputDecoration(labelText: 'Severity (0–5 or % area)'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _remarks,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                    )),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    onPressed: _save,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final provider = context.read<DiagnosticsProvider>();

    provider.add(DiagnosisEntry(
      date: _date,
      farmerOrFieldId: _farmerId.text.trim(),
      description: _desc.text.trim(),
      imagePaths: List.of(_images),
      category: _category,
      predictedIssue: _predicted.isEmpty ? '—' : _predicted,
      confidence: _confidence,
      recommendedAction: _action.text.trim(),
      severity: _severity.text.trim(),
      remarks: _remarks.text.trim(),
    ));

    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Diagnosis saved')));
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}
