class DiagnosisEntry {
  final DateTime date;
  final String farmerOrFieldId;
  final String description;          // free text symptoms/notes
  final List<String> imagePaths;     // local file paths (camera/gallery)
  final String category;             // Disease/Pest/Nutrient/Weed/Other
  final String predictedIssue;       // AI top guess (mock)
  final int confidence;              // %
  final String recommendedAction;    // AI recommendation
  final String severity;             // "0–5" or "% area" text
  final String remarks;              // additional notes

  DiagnosisEntry({
    required this.date,
    required this.farmerOrFieldId,
    required this.description,
    required this.imagePaths,
    required this.category,
    required this.predictedIssue,
    required this.confidence,
    required this.recommendedAction,
    required this.severity,
    required this.remarks,
  });
}
