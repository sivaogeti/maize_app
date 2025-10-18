// lib/features/inputs/inputs_details_screen.dart
import 'dart:io';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import 'dart:typed_data';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // for Timestamp -> Date
import '../../core/services/auth_service.dart';
import '../../core/services/input_issues_provider.dart';

import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'dart:async';

final me = FirebaseAuth.instance.currentUser;

const String kInputDetailsCollection = 'input_issues';

class InputsDetailsScreen extends StatefulWidget {
  const InputsDetailsScreen({super.key, required this.docId});
  final String docId;

  @override
  State<InputsDetailsScreen> createState() => _InputsDetailsScreenState();

}


class _InputsDetailsScreenState extends State<InputsDetailsScreen> {

  // inside _InputsDetailsScreenState (class level)
  List<String>? _inchargeIds;        // <-- holds the values
  String? _selectedIncharge;         // <-- current selection

  // Farmer / Field IDs for the dropdown
  List<String> _farmerIds = const [];
  String? _selectedFarmerOrFieldId;        // if not already present

  // Keep the stream subscription so we can cancel it
  StreamSubscription<List<String>>? _inchSub;


  // Formats either a Firestore Timestamp or a DateTime to yyyy-MM-dd
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  String _fmt(dynamic v) {
    if (v == null) return '';
    try {
      if (v is Timestamp) return _df.format(v.toDate());
      if (v is DateTime)  return _df.format(v);
      return v.toString();
    } catch (_) {
      return v.toString();
    }
  }

  Stream<List<String>> farmerIds$() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Build a Query (NOT a Stream yet!)
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('input_issues')
        .where('orgPathUids', arrayContains: uid);   // align with rules

    // (optional) filter by selected FI
    if (_selectedIncharge != null && _selectedIncharge!.isNotEmpty) {
      q = q.where('fieldInchargeUid', isEqualTo: _selectedIncharge);
    }

    // Apply ordering last, then turn into a Stream
    q = q.orderBy('dateOfIssue', descending: true);  // may require an index

    return q.snapshots().map((snap) {
      final set = <String>{};
      for (final d in snap.docs) {
        final id = (d.data()['farmerOrFieldId'] ?? '').toString().trim();
        if (id.isNotEmpty) set.add(id);
      }
      final list = set.toList()..sort();
      return list;
    });
  }




  List<DropdownMenuItem<String>> get _farmerIdItems =>
      (_farmerIds).map((id) => DropdownMenuItem<String>(
        value: id,
        child: Text(id),
      )).toList();

  Widget _idDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFarmerOrFieldId,
      isExpanded: true,
      items: _farmerIdItems,
      onChanged: (v) => setState(() => _selectedFarmerOrFieldId = v),
      decoration: const InputDecoration(
        labelText: 'Farmer / Field ID',
        prefixIcon: Icon(Icons.badge_outlined),
        border: OutlineInputBorder(),
      ),
      hint: const Text('Farmer / Field ID'),
    );
  }


  /// Builds menu items for a list of IDs.
  List<DropdownMenuItem<String>> _buildFarmerIdItems(List<String> ids) =>
      ids.map((id) => DropdownMenuItem<String>(value: id, child: Text(id))).toList();


  void smartBack(BuildContext context) {
    // 1) Close dialogs/sheets shown with rootNavigator: true
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop();
      return;
    }

    // 2) Pop GoRouter stack if possible
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    // Nothing to pop → go to the list page
    router.goNamed('fi.inputs.supply.list'); // <-- not '/inputs'
  }


  @override
  void initState() {
    super.initState();
    _inchSub = inchargeIds$().listen((ids) {
      setState(() {
        _inchargeIds = ids;
        _selectedIncharge ??= ids.isNotEmpty ? ids.first : null;
      });
    });
  }

  @override
  void dispose() {
    _inchSub?.cancel();
    super.dispose();
  }

  /// Stream of Field Incharge user IDs / names from Firestore.

  /// Stream of Field Incharge user IDs from Firestore.
  Stream<List<String>> inchargeIds$() {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return const Stream.empty();

    // Only ONE array-contains on the query (orgPathUids).
    return FirebaseFirestore.instance
        .collection('users')
        .where('orgPathUids', arrayContains: me.uid)
        .snapshots()
        .map((snap) {
      return snap.docs
      // Filter role on the client to avoid a second array-contains.
          .where((d) {
        final data = d.data();
        final role = data['role'];                // scalar role (if present)
        final roles = (data['roles'] as List?) ?? const [];
        return role == 'field_incharge' || roles.contains('field_incharge');
      })
          .map((d) => d.id)                           // or use a display field if needed
          .toList();
    });
  }



  List<DropdownMenuItem<String>> get _inchargeItems =>
      (_inchargeIds ?? const <String>[])
          .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
          .toList();

  Widget _inchargeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedIncharge,
      isExpanded: true,
      items: _inchargeItems,
      onChanged: (v) {
        setState(() => _selectedIncharge = v);
        //_refreshQuery(); // if you need to filter the list below
      },
      decoration: const InputDecoration(
        labelText: 'Field Incharge',
        prefixIcon: Icon(Icons.assignment_ind_outlined),
        border: OutlineInputBorder(),
      ),
      hint: const Text('Field Incharge'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection(kInputDetailsCollection);

    String _fmt(dynamic v) {
      if (v == null) return '';
      try {
        if (v is Timestamp) {
          return DateFormat('yyyy-MM-dd').format(v.toDate());
        }
        if (v is DateTime) {
          return DateFormat('yyyy-MM-dd').format(v);
        }
        return v.toString();
      } catch (_) {
        return v.toString();
      }
    }

    return PopScope(
      canPop: false, // we’ll decide what “back” should do
      onPopInvoked: (didPop) {
        if (!didPop) smartBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Input Supply Tracker'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => smartBack(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () {
                try {
                  context.read<AuthService>().logout();
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
        body: Consumer<InputIssuesProvider>(
          builder: (context, prov, _) {
            final items = prov.items; // live Firestore stream

            if (items.isEmpty) {
              return const Center(child: Text('No input issues yet'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = items[i];           // InputIssueView
                final d  = it.raw;            // Map<String, dynamic>

                final id   = (d['farmerOrFieldId'] ?? '') as String;
                //final when = (d['dateOfIssue'] is Timestamp)
                  //  ? (d['dateOfIssue'] as Timestamp).toDate()
                    //: DateTime.now();
                final itemType = (d['itemType'] ?? '') as String;
                //final qty = (d['quantityIssued'] ?? 0).toString();

                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text('$id • $itemType'),
                  subtitle: Text('${_fmt(d['dateOfIssue'])}  •  Qty: ${(d['quantityIssued'] ?? 0).toString()}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showIssueDetails(context as BuildContext, it), // keep your detail/sheet
                );
              },
            );
          },
        ),
      ),
    );

  }

  void _showIssueDetails(BuildContext context, InputIssueView it) {
    final d = it.raw; // Map<String, dynamic> from the provider
    final String? photoPath   = (d['photoPath'] as String?)?.trim();
    final String? signatureB64= (d['signaturePng'] as String?)?.trim();

    Uint8List? sigBytes;
    if (signatureB64 != null && signatureB64.isNotEmpty) {
      try { sigBytes = base64Decode(signatureB64); } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inchargeDropdown(),
              const SizedBox(height: 8),
              _idDropdown(),
            ],
          ),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: 8),
                      Text('Input Supply Details', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),

                  kv('Date', _fmt(d['dateOfIssue'])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: StreamBuilder<List<String>>(
                      stream: farmerIds$(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
                        }
                        final ids = snap.data ?? const <String>[];
                        if (ids.isEmpty) {
                          return const SizedBox(
                            height: 56,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('No Farmer / Field IDs found'),
                            ),
                          );
                        }
                        return _idDropdown();
                      },
                    ),
                  ),


                  kv('Crop & Stage', (d['cropAndStage'] ?? '').toString()),

                  const Divider(),
                  kv('Item Type', (d['itemType'] ?? '').toString()),
                  kv('Brand / Grade', (d['brandOrGrade'] ?? '').toString()),
                  kv('Batch / Lot No.', (d['batchOrLotNo'] ?? '').toString()),
                  kv('Unit of Measure', (d['unitOfMeasure'] ?? '').toString()),
                  kv('Quantity Issued', (d['quantityIssued'] ?? 0).toString()),

                  const Divider(),
                  kv('Issued By', (d['issuedBy'] ?? '').toString()),
                  kv('Received By', (d['receivedBy'] ?? '').toString()),

                  if ((d['advanceAmount'] ?? '').toString().isNotEmpty) kv('Advance Amount', d['advanceAmount'].toString()),
                  if ((d['remarks'] ?? '').toString().isNotEmpty) kv('Remarks', (d['remarks'] ?? '').toString()),

                  if ((photoPath ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Attachment', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(photoPath!), height: 160, fit: BoxFit.cover),
                    ),
                  ],

                  if (sigBytes != null) ...[
                    const SizedBox(height: 12),
                    Text('Signature', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.memory(sigBytes, fit: BoxFit.contain),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
