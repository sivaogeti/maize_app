import 'package:flutter/material.dart';
import '../../core/widgets/app_drawer.dart';

class FieldActivityLogScreen extends StatefulWidget {
  const FieldActivityLogScreen({super.key});

  @override
  State<FieldActivityLogScreen> createState() => _FieldActivityLogScreenState();
}

class _FieldActivityLogScreenState extends State<FieldActivityLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmerId = TextEditingController();
  DateTime _date = DateTime.now();
  String _activity = 'Sowing';
  final _notes = TextEditingController();

  final _activities = const ['Sowing', 'Irrigation', 'Fertilizer', 'Weeding', 'Pest Control', 'Harvest'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Activity Log')),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _farmerId, decoration: const InputDecoration(labelText: 'Farmer ID / Name'), validator: _req),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Date: ${_date.toLocal().toString().split(' ').first}')),
                  TextButton(onPressed: _pickDate, child: const Text('Change')),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _activity,
                items: _activities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setState(() => _activity = v ?? _activity),
                decoration: const InputDecoration(labelText: 'Activity'),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Save Entry'))),
            ],
          ),
        ),
      ),
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity saved (mock). Connect API later.')));
  }
}
