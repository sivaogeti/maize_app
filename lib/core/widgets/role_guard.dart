import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_clean/core/services/auth_service.dart';

// lib/core/widgets/role_guard.dart
class RoleGuard extends StatelessWidget {
  const RoleGuard({super.key, required this.child, this.allowedRoles = const {}});
  final Widget child;
  final Set<String> allowedRoles; // empty => any signed-in user

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Not signed in
    if (auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }

    // Signed in but profile not loaded yet -> wait
    if (auth.role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Normalize role strings
    final userRole = auth.role!.trim().toLowerCase();
    final allowed = allowedRoles.map((r) => r.trim().toLowerCase()).toSet();

    final allowedByRole =
        auth.isSuper || allowed.isEmpty || allowed.contains(userRole);

    // inside RoleGuard.build, before returning:
    //debugPrint('RoleGuard -> userRole=${_norm(auth.role!)}  allowed=${allowed.map(_norm).toSet()}');


    return allowedByRole
        ? child
        : const Scaffold(body: Center(child: Text('Unauthorized')));
  }
}
