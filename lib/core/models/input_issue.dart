import 'dart:convert';

class InputIssue {
  final DateTime dateOfIssue;
  final String farmerOrFieldId;
  final String cropAndStage;
  final String itemType;
  final String brandOrGrade;
  final String batchOrLotNo;
  final String unitOfMeasure;
  final double quantityIssued;
  final String issuedBy;
  final bool receivedBy;
  final double? advanceAmount;
  final String? remarks;

  // NEW attachments
  final String? photoPath;     // local device path; later move to Storage URL
  final String? signaturePng;  // base64-encoded PNG bytes

  InputIssue({
    required this.dateOfIssue,
    required this.farmerOrFieldId,
    required this.cropAndStage,
    required this.itemType,
    required this.brandOrGrade,
    required this.batchOrLotNo,
    required this.unitOfMeasure,
    required this.quantityIssued,
    required this.issuedBy,
    required this.receivedBy,
    this.advanceAmount,
    this.remarks,
    this.photoPath,      // NEW
    this.signaturePng,   // NEW
  });

  Map<String, dynamic> toJson() => {
    'dateOfIssue': dateOfIssue.toIso8601String(),
    'farmerOrFieldId': farmerOrFieldId,
    'cropAndStage': cropAndStage,
    'itemType': itemType,
    'brandOrGrade': brandOrGrade,
    'batchOrLotNo': batchOrLotNo,
    'unitOfMeasure': unitOfMeasure,
    'quantityIssued': quantityIssued,
    'issuedBy': issuedBy,
    'receivedBy': receivedBy,
    'advanceAmount': advanceAmount,
    'remarks': remarks,
    // NEW
    'photoPath': photoPath,
    'signaturePng': signaturePng,
  };

  factory InputIssue.fromJson(Map<String, dynamic> json) => InputIssue(
    dateOfIssue: DateTime.tryParse(json['dateOfIssue'] as String? ?? '') ?? DateTime.now(),
    farmerOrFieldId: json['farmerOrFieldId'] as String? ?? '',
    cropAndStage: json['cropAndStage'] as String? ?? '',
    itemType: json['itemType'] as String? ?? '',
    brandOrGrade: json['brandOrGrade'] as String? ?? '',
    batchOrLotNo: json['batchOrLotNo'] as String? ?? '',
    unitOfMeasure: json['unitOfMeasure'] as String? ?? '',
    quantityIssued: (json['quantityIssued'] is num)
        ? (json['quantityIssued'] as num).toDouble()
        : 0.0,
    issuedBy: json['issuedBy'] as String? ?? '',
    receivedBy: json['receivedBy'] as bool? ?? false,
    advanceAmount: (json['advanceAmount'] is num)
        ? (json['advanceAmount'] as num).toDouble()
        : null,
    remarks: json['remarks'] as String?,
    // NEW
    photoPath: json['photoPath'] as String?,
    signaturePng: json['signaturePng'] as String?,
  );

  String encode() => jsonEncode(toJson());
}
