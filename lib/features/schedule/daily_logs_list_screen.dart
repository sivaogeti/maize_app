// daily_logs_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';

CollectionReference<Map<String, dynamic>> _userLogsCol(String uid) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_logs');

class DailyLogsListScreen extends StatefulWidget {
  const DailyLogsListScreen({super.key});

  @override
  State<DailyLogsListScreen> createState() => _DailyLogsListScreenState();
}

class _DailyLogsListScreenState extends State<DailyLogsListScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final List<LatLng> _route = [];
  Polyline? _polyline;
  bool _isTracking = false;
  double _distanceMeters = 0.0;
  StreamSubscription<Position>? _positionStreamSub;
  CameraPosition _initialCamera = const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 5); // India center fallback

  static const PolylineId _polyId = PolylineId('route_polyline');

  @override
  void initState() {
    super.initState();
    _polyline = Polyline(
      polylineId: _polyId,
      points: _route,
      width: 5,
      consumeTapEvents: false,
    );
    _determinePosition().then((pos) {
      if (pos != null) {
        final camera = CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16);
        setState(() => _initialCamera = camera);
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  void _startTracking() async {
    final pos = await _determinePosition();
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied or service disabled')));
      return;
    }

    setState(() {
      _isTracking = true;
      _route.clear();
      _distanceMeters = 0.0;
      _polyline = _polyline!.copyWith(pointsParam: _route);
    });

    // Move camera to start pos
    final GoogleMapController ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));

    // Subscribe to position stream
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((Position position) {
      final newLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        if (_route.isNotEmpty) {
          _distanceMeters += Geolocator.distanceBetween(
            _route.last.latitude,
            _route.last.longitude,
            newLatLng.latitude,
            newLatLng.longitude,
          );
        }
        _route.add(newLatLng);
        _polyline = _polyline!.copyWith(pointsParam: List<LatLng>.from(_route));
      });
      // keep camera following user
      ctrl.animateCamera(CameraUpdate.newLatLng(newLatLng));
    });
  }

  void _stopTracking() async {
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
    setState(() {
      _isTracking = false;
    });

    // Optionally: save to Firestore here
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = _userLogsCol(user.uid).doc();
      await doc.set({
        'timestamp': FieldValue.serverTimestamp(),
        'distance_m': _distanceMeters,
        'route': _route.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log saved')));
  }

  String _formattedDistance() {
    if (_distanceMeters < 1000) {
      return '${_distanceMeters.toStringAsFixed(1)} m';
    } else {
      return '${(_distanceMeters / 1000).toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If your previous screen had inputs above the map, re-add them here.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logs & Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: _initialCamera,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              polylines: _polyline != null ? {_polyline!} : {},
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) _mapController.complete(controller);
              },
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GPS Coverage', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(children: [
                      ElevatedButton.icon(
                        onPressed: _isTracking ? null : _startTracking,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(elevation: 0),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isTracking ? _stopTracking : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Finish'),
                        style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(_formattedDistance(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
        // Below the map you can show save button / logs list (use your existing widgets)
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Reuse stop to make sure tracking ended before saving
              if (_isTracking) {
                _stopTracking();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active tracking to save.')));
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Log'),
          ),
        ),
      ]),
    );
  }
}
