import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'
    show kReleaseMode, defaultTargetPlatform, TargetPlatform;

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'core/services/auth_service.dart';
import 'core/services/farmers_provider.dart';
import 'core/services/input_issues_provider.dart';
import 'core/services/field_observations_provider.dart';
import 'core/services/observations_provider.dart';
import 'core/services/inputs_provider.dart';
import 'core/services/activity_schedule_provider.dart';
import 'core/services/diagnostics_provider.dart';
import 'core/services/field_diagnostics_provider.dart';
import 'core/services/daily_logs_provider.dart';

import 'routing/router.dart';

/// Use the Firestore emulator in debug/profile only.
/// Call this AFTER Firebase.initializeApp() but BEFORE creating providers.
Future<void> _pointFirestoreToEmulatorIfNeeded() async {
  if (kReleaseMode) return;

  // Android emulator reaches host via 10.0.2.2; others use localhost.
  final host = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFirestore.instance.settings = const Settings(
    sslEnabled: false,
    persistenceEnabled: false,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    // Safe on hot-restart or when native auto-init already ran.
    if (e.code != 'duplicate-app') rethrow;
  }

  // <<< IMPORTANT: point to emulator before any Firestore usage
  //await _pointFirestoreToEmulatorIfNeeded();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
            create: (_) => FarmersProvider(FirebaseFirestore.instance)),
        ChangeNotifierProvider(create: (_) {
          final p = InputIssuesProvider(FirebaseFirestore.instance);
          p.bind();
          return p;
        }),
        ChangeNotifierProvider(
            create: (_) =>
            FieldObservationsProvider(FirebaseFirestore.instance)..bind()),
        ChangeNotifierProvider(create: (_) => ObservationsProvider()),
        ChangeNotifierProvider(create: (_) => InputsProvider()),
        ChangeNotifierProvider(create: (_) => ActivityScheduleProvider()),
        ChangeNotifierProvider(create: (_) => DiagnosticsProvider()),
        ChangeNotifierProvider(
            create: (_) =>
                FieldDiagnosticsProvider(FirebaseFirestore.instance)),
        ChangeNotifierProvider(
            create: (_) => DailyLogsProvider(FirebaseFirestore.instance)),
      ],
      child: AppRouter(),
    ),
  );
}
