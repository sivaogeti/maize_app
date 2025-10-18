// lib/core/services/inputs_provider.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../models/input_issue.dart';

class InputsProvider extends ChangeNotifier {
  final List<InputIssue> _items = [
    // sample rows (safe to delete)
    InputIssue(
      dateOfIssue: DateTime(2025, 5, 1),
      farmerOrFieldId: 'F-01',
      cropAndStage: 'Maize – Vegetative',
      itemType: 'Fertiliser',
      brandOrGrade: '20:20:15',
      batchOrLotNo: 'L23-A',
      unitOfMeasure: 'kg',
      quantityIssued: 100,
      issuedBy: 'J. Rao',
      receivedBy: true, // farmer sign/photo attached
      advanceAmount: null,
      remarks: 'First top-dressing',
    ),
    InputIssue(
      dateOfIssue: DateTime(2025, 5, 3),
      farmerOrFieldId: 'F-02',
      cropAndStage: 'Maize – Sowing',
      itemType: 'Seed',
      brandOrGrade: 'Hybrid XYZ',
      batchOrLotNo: 'S45-B',
      unitOfMeasure: 'kg',
      quantityIssued: 15,
      issuedBy: 'A. Singh',
      receivedBy: false,
      advanceAmount: 0,
      remarks: '—',
    ),
  ];

  UnmodifiableListView<InputIssue> get items => UnmodifiableListView(_items);

  void add(InputIssue issue) {
    _items.add(issue);
    notifyListeners();
  }

  void addAll(Iterable<InputIssue> issues) {
    _items.addAll(issues);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Simple filter by farmer/field id or free-text on a few columns.
  List<InputIssue> filter({String? farmerOrFieldId, String? q}) {
    final query = (q ?? '').toLowerCase();
    return _items.where((r) {
      final okId = farmerOrFieldId == null ||
          farmerOrFieldId.isEmpty ||
          r.farmerOrFieldId.toLowerCase() == farmerOrFieldId.toLowerCase();
      final okQ = query.isEmpty ||
          r.farmerOrFieldId.toLowerCase().contains(query) ||
          r.cropAndStage.toLowerCase().contains(query) ||
          r.itemType.toLowerCase().contains(query) ||
          r.brandOrGrade.toLowerCase().contains(query) ||
          r.remarks?.toLowerCase().contains(query) == true;
      return okId && okQ;
    }).toList();
  }
}
