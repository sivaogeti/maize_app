// lib/core/models/daily_log.dart
import 'dart:convert';

class GpsPoint {
  final double lat;
  final double lng;
  final DateTime t;

  const GpsPoint({required this.lat, required this.lng, required this.t});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 't': t.toIso8601String()};
  factory GpsPoint.fromJson(Map<String, dynamic> j) =>
      GpsPoint(lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble(), t: DateTime.parse(j['t'] as String));
}

class DailyLog {
  final DateTime date;

  // Renamed per requirement (auto-populated from Registration)
  final String fieldId;

  final String farmerName;
  final String villageLocation;

  // Moved after village/location
  final String activitiesPerformed;

  final String? inputsSupplied;
  final String? observationsIssues;
  final String? nextActionFollowUp;

  // Check-ins/photos (simple toggles)
  final bool gpsCheckIn;
  final bool photosAttached;

  // Optional signature image (base64 PNG)
  final String? signaturePngBase64;

  // GPS coverage
  final double distanceKm; // computed total distance for the day
  final List<GpsPoint> track; // optional polyline points

  const DailyLog({
    required this.date,
    required this.fieldId,
    required this.farmerName,
    required this.villageLocation,
    required this.activitiesPerformed,
    this.inputsSupplied,
    this.observationsIssues,
    this.nextActionFollowUp,
    required this.gpsCheckIn,
    required this.photosAttached,
    this.signaturePngBase64,
    required this.distanceKm,
    required this.track,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'fieldId': fieldId,
    'farmerName': farmerName,
    'villageLocation': villageLocation,
    'activitiesPerformed': activitiesPerformed,
    'inputsSupplied': inputsSupplied,
    'observationsIssues': observationsIssues,
    'nextActionFollowUp': nextActionFollowUp,
    'gpsCheckIn': gpsCheckIn,
    'photosAttached': photosAttached,
    'signaturePngBase64': signaturePngBase64,
    'distanceKm': distanceKm,
    'track': track.map((e) => e.toJson()).toList(),
  };

  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
    date: DateTime.parse(j['date'] as String),
    fieldId: j['fieldId'] as String,
    farmerName: j['farmerName'] as String,
    villageLocation: j['villageLocation'] as String,
    activitiesPerformed: j['activitiesPerformed'] as String,
    inputsSupplied: j['inputsSupplied'] as String?,
    observationsIssues: j['observationsIssues'] as String?,
    nextActionFollowUp: j['nextActionFollowUp'] as String?,
    gpsCheckIn: j['gpsCheckIn'] as bool,
    photosAttached: j['photosAttached'] as bool,
    signaturePngBase64: j['signaturePngBase64'] as String?,
    distanceKm: (j['distanceKm'] as num).toDouble(),
    track: (j['track'] as List<dynamic>).map((e) => GpsPoint.fromJson(e as Map<String, dynamic>)).toList(),
  );

  String encode() => jsonEncode(toJson());
  static DailyLog decode(String s) => DailyLog.fromJson(jsonDecode(s));
}
