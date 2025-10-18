import 'package:flutter/foundation.dart';
import '../models/diagnosis.dart';

class DiagnosticsProvider extends ChangeNotifier {
  final List<DiagnosisEntry> _items = [
    DiagnosisEntry(
      date: DateTime(2025, 5, 1),
      farmerOrFieldId: 'F-01',
      description: 'Irregular brown lesions on leaves, humid weather.',
      imagePaths: const [],
      category: 'Disease',
      predictedIssue: 'Leaf blight',
      confidence: 90,
      recommendedAction: 'Spray Mancozeb @2 g/L; ensure canopy aeration.',
      severity: '3 (≈25%)',
      remarks: 'Monitor 3–4 days',
    ),
  ];

  List<DiagnosisEntry> get items => List.unmodifiable(_items);

  void add(DiagnosisEntry e) {
    _items.add(e);
    notifyListeners();
  }
}
