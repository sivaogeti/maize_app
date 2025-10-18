// lib/core/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

String _prettyRole(String role) {
  switch (role) {
    case 'fieldIncharge':
      return 'Field Incharge';
    case 'clusterIncharge':
      return 'Cluster Incharge';
    case 'territoryIncharge':
      return 'Territory Incharge';
    case 'customerSupport':
      return 'Customer Support';
    case 'manager':
      return 'Manager';
    case 'admin':
      return 'Admin';
    case 'farmer':
      return 'Farmer';
    default:
      return role;
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser; // AppUser? with id, role

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.uid ?? 'Guest'),
            accountEmail: Text(user == null ? 'Not signed in' : _prettyRole(user.role as String)),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => context.go('/'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Communication'),
            onTap: () => context.go('/communication'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => context.go('/settings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              auth.logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
