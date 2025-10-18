// lib/features/settings/settings_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart'; // adjust path if needed


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _eduCtrl = TextEditingController();
  final _expCtrl = TextEditingController(); // years
  final _villagesCtrl = TextEditingController(); // comma-separated
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  File? _photoFile;

  bool _loading = true;

  // ---- helpers ----
  InputDecoration _dec(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: false,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: suffix,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _eduCtrl.dispose();
    _expCtrl.dispose();
    _villagesCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('settings.profile');
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _nameCtrl.text = map['name'] ?? '';
        _eduCtrl.text = map['education'] ?? '';
        _expCtrl.text = (map['experience'] ?? '').toString();
        _villagesCtrl.text = (map['villages'] ?? []) is List
            ? (map['villages'] as List).join(', ')
            : (map['villages'] ?? '');
        _mobileCtrl.text = map['mobile'] ?? '';
        _addressCtrl.text = map['address'] ?? '';
        final path = map['photoPath'];
        if (path is String && path.isNotEmpty && File(path).existsSync()) {
          _photoFile = File(path);
        }
      } catch (_) {
        // ignore corrupted state
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final villages = _villagesCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final map = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'education': _eduCtrl.text.trim(),
      'experience': int.tryParse(_expCtrl.text.trim()) ?? 0,
      'villages': villages,
      'mobile': _mobileCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'photoPath': _photoFile?.path ?? '',
    };

    final sp = await SharedPreferences.getInstance();
    await sp.setString('settings.profile', jsonEncode(map));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.of(context).maybePop(map);
  }

  Future<void> _pickPhoto(ImageSource src) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: src, imageQuality: 80);
    if (x != null) {
      setState(() => _photoFile = File(x.path));
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.camera);
            },
          ),
          if (_photoFile != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove photo'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _photoFile = null);
              },
            ),
        ]),
      ),
    );
  }

  String? _required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  String? _validateMobile(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Mobile number is required';
    // Accept 10 digits (India) or +country formats with digits/spaces
    final re = RegExp(r'^\+?[0-9 ]{10,15}$');
    if (!re.hasMatch(s)) return 'Enter a valid phone number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();           // normal back
            } else {
              context.go('/');         // fallback home (change path/name as needed)
              // or: context.goNamed('home');
            }
          },
        ),
        actions: [
            // 1) View saved FIRST, so it’s always visible
            IconButton(
              icon: const Icon(Icons.list_alt_outlined),
              tooltip: 'View saved',
              onPressed: () => context.push('/settings/settings/saved'),
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

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Photo
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage:
                          _photoFile != null ? FileImage(_photoFile!) : null,
                          child: _photoFile == null
                              ? const Icon(Icons.person, size: 44)
                              : null,
                        ),
                        InkWell(
                          onTap: _showPhotoSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Add a profile photo (optional)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Name'),
                  validator: (v) => _required(v, field: 'Name'),
                ),
                const SizedBox(height: 12),

                // Education Qualification
                TextFormField(
                  controller: _eduCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Education Qualification',
                      hint: 'e.g., B.Sc. (Agri), Diploma…'),
                  validator: (v) =>
                      _required(v, field: 'Education Qualification'),
                ),
                const SizedBox(height: 12),

                // Experience (years)
                TextFormField(
                  controller: _expCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration:
                  _dec('Experience', hint: 'Years (e.g., 3)'),
                  validator: (v) =>
                      _required(v, field: 'Experience (years)'),
                ),
                const SizedBox(height: 12),

                // Allocated Villages (comma separated)
                TextFormField(
                  controller: _villagesCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Allocated Villages',
                      hint: 'Comma-separated (e.g., Village A, Village B)'),
                  validator: (v) =>
                      _required(v, field: 'Allocated Villages'),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Mobile
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))
                  ],
                  decoration: _dec('Mobile Number'),
                  validator: _validateMobile,
                ),
                const SizedBox(height: 12),

                // Permanent Address
                TextFormField(
                  controller: _addressCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Permanent Address'),
                  minLines: 3,
                  maxLines: 5,
                  validator: (v) =>
                      _required(v, field: 'Permanent Address'),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
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
}
