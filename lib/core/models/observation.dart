// lib/core/models/observation.dart
import 'dart:convert';

class Observation {
  final DateTime date;
  final String farmerId;

  // Field context
  final String cropAndStage;                 // e.g., "Maize – Vegetative"
  final String category;                     // Disease/Pest/Weed/Nutrient/Water/Crop damage
  final String problemIdentified;            // free text
  final int severity;                        // 0-5 or % area (you choose interpretation)
  final String actionRecommended;            // FIC recommendation
  final bool photosAttached;                 // any photo captured

  // AI
  final int? aiConfidence;                   // %
  final String? aiRecommendedAction;

  // Follow up
  final DateTime? followUpDate;
  final bool gpsCheckin;                     // Y/N in the sheet
  final String? remarks;

  // Consent (new)
  final String? consentPhotoPath;            // local path
  final String? signaturePngBase64;          // PNG as base64

  // Extra: attach path list if you want multiple photos
  final List<String> attachmentPaths;

  const Observation({
    required this.date,
    required this.farmerId,
    required this.cropAndStage,
    required this.category,
    required this.problemIdentified,
    required this.severity,
    required this.actionRecommended,
    required this.photosAttached,
    this.aiConfidence,
    this.aiRecommendedAction,
    this.followUpDate,
    required this.gpsCheckin,
    this.remarks,
    this.consentPhotoPath,
    this.signaturePngBase64,
    this.attachmentPaths = const [],
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'farmerId': farmerId,
    'cropAndStage': cropAndStage,
    'category': category,
    'problemIdentified': problemIdentified,
    'severity': severity,
    'actionRecommended': actionRecommended,
    'photosAttached': photosAttached,
    'aiConfidence': aiConfidence,
    'aiRecommendedAction': aiRecommendedAction,
    'followUpDate': followUpDate?.toIso8601String(),
    'gpsCheckin': gpsCheckin,
    'remarks': remarks,
    'consentPhotoPath': consentPhotoPath,
    'signaturePngBase64': signaturePngBase64,
    'attachmentPaths': attachmentPaths,
  };

  factory Observation.fromJson(Map<String, dynamic> j) => Observation(
    date: DateTime.parse(j['date'] as String),
    farmerId: j['farmerId'] as String,
    cropAndStage: j['cropAndStage'] as String,
    category: j['category'] as String,
    problemIdentified: j['problemIdentified'] as String,
    severity: (j['severity'] as num).toInt(),
    actionRecommended: j['actionRecommended'] as String,
    photosAttached: j['photosAttached'] as bool,
    aiConfidence: j['aiConfidence'] as int?,
    aiRecommendedAction: j['aiRecommendedAction'] as String?,
    followUpDate: j['followUpDate'] == null
        ? null
        : DateTime.parse(j['followUpDate'] as String),
    gpsCheckin: j['gpsCheckin'] as bool,
    remarks: j['remarks'] as String?,
    consentPhotoPath: j['consentPhotoPath'] as String?,
    signaturePngBase64: j['signaturePngBase64'] as String?,
    attachmentPaths: (j['attachmentPaths'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );

  String encode() => jsonEncode(toJson());
}
