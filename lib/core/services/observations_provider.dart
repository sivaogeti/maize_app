// lib/core/services/observations_provider.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../models/observation.dart';

class ObservationsProvider extends ChangeNotifier {
  final List<Observation> _items = [
    // (optional) a couple of seed rows you can delete later
    Observation(
      date: DateTime.now(),
      farmerId: 'cumbum_prasad_1',
      cropAndStage: 'Maize – Vegetative',
      category: 'Disease',
      problemIdentified: 'Leaf blight suspected',
      severity: 2,
      actionRecommended: 'Scout again in 3 days',
      photosAttached: false,
      aiConfidence: null,
      aiRecommendedAction: null,
      followUpDate: null,
      gpsCheckin: false,
      remarks: 'North plot only',
      consentPhotoPath: null,
      signaturePngBase64: null,
      attachmentPaths: const [],
    ),
    Observation(
      date: DateTime.now().subtract(const Duration(days: 1)),
      farmerId: 'cumbum_ramana_7',
      cropAndStage: 'Maize – Tasseling',
      category: 'Nutrient',
      problemIdentified: 'Nitrogen deficiency',
      severity: 3,
      actionRecommended: 'Foliar urea 2%',
      photosAttached: true,
      aiConfidence: 76,
      aiRecommendedAction: 'Apply 2% urea spray (mock)',
      followUpDate: null,
      gpsCheckin: true,
      remarks: null,
      consentPhotoPath: null,
      signaturePngBase64: null,
      attachmentPaths: const [],
    ),
  ];

  UnmodifiableListView<Observation> get items => UnmodifiableListView(_items);

  void add(Observation o) {
    _items.add(o);
    notifyListeners();
  }

  void addAll(Iterable<Observation> list) {
    _items.addAll(list);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void removeWhere(bool Function(Observation o) test) {
    _items.removeWhere(test);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Replace item at [index] with [updated].
  void updateAt(int index, Observation updated) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = updated;
    notifyListeners();
  }

  /// Returns a copy filtered by farmer/field id or category, etc.
  List<Observation> filter({String? farmerId, String? category, String? q}) {
    final qq = (q ?? '').toLowerCase();
    return _items.where((o) {
      final okFarmer = farmerId == null || farmerId.isEmpty || o.farmerId.toLowerCase() == farmerId.toLowerCase();
      final okCat = category == null || category.isEmpty || o.category.toLowerCase() == category.toLowerCase();
      final okQuery = qq.isEmpty ||
          o.farmerId.toLowerCase().contains(qq) ||
          o.category.toLowerCase().contains(qq) ||
          o.problemIdentified.toLowerCase().contains(qq) ||
          o.cropAndStage.toLowerCase().contains(qq);
      return okFarmer && okCat && okQuery;
    }).toList();
  }
}
