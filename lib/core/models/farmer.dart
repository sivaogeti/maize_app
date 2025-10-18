import 'package:cloud_firestore/cloud_firestore.dart';

class Farmer {
  final String id;                   // FR_<v>_<n>_<id>
  final String name;
  final String so;
  final String phone;

  // Optional domain fields used across screens
  final String? residenceVillage;
  final String? cropVillage;
  final String? cluster;
  final String? territory;
  final String? season;
  final String? hybrid;
  final num?    plantedArea;
  final String? waterSource;
  final String? previousCrop;
  final String? soilType;
  final String? soilTexture;

  // Media (if you store local path / url later)
  final String? photoPath;
  final String? signaturePng;

  // Metadata
  final String? createdBy;
  final Timestamp? createdAt;

  const Farmer({
    required this.id,
    required this.name,
    required this.so,
    required this.phone,
    this.residenceVillage,
    this.cropVillage,
    this.cluster,
    this.territory,
    this.season,
    this.hybrid,
    this.plantedArea,
    this.waterSource,
    this.previousCrop,
    this.soilType,
    this.soilTexture,
    this.photoPath,
    this.signaturePng,
    this.createdBy,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'residenceVillage': residenceVillage,
    'cropVillage': cropVillage,
    'cluster': cluster,
    'territory': territory,
    'season': season,
    'hybrid': hybrid,
    'proposedArea': plantedArea,
    'waterSource': waterSource,
    'previousCrop': previousCrop,
    'soilType': soilType,
    'photoPath': photoPath,
    'signaturePng': signaturePng,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };

  factory Farmer.fromMap(Map<String, dynamic> m) => Farmer(
    id: (m['id'] as String?) ?? '',
    name: (m['name'] as String?) ?? '',
    so: (m['so'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    residenceVillage: m['residenceVillage'] as String?,
    cropVillage: m['cropVillage'] as String?,
    cluster: m['cluster'] as String?,
    territory: m['territory'] as String?,
    season: m['season'] as String?,
    hybrid: m['hybrid'] as String?,
    plantedArea: (m['proposedArea'] is int || m['proposedArea'] is double)
        ? (m['proposedArea'] as num)
        : null,
    waterSource: m['waterSource'] as String?,
    previousCrop: m['previousCrop'] as String?,
    soilType: m['soilType'] as String?,
    photoPath: m['photoPath'] as String?,
    signaturePng: m['signaturePng'] as String?,
    createdBy: m['createdBy'] as String?,
    createdAt: m['createdAt'] is Timestamp ? m['createdAt'] as Timestamp : null,
  );

  factory Farmer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Farmer.fromMap(doc.data() ?? {}) ;
}
