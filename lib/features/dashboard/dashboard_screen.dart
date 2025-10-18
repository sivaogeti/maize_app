import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/roles.dart';
import '../../core/services/auth_service.dart';




/// ---------- Helper: resilient navigation (go_router or MaterialApp routes) ----------
void _nav(BuildContext context, String route) {
  // Try go_router if present
  try {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    // Many apps expose context.go via go_router extension; if not available, this throws
    // and we fall back to MaterialApp named routes.
    // The analyzer may warn but this keeps runtime safe.
    // dynamic go = (context as dynamic).go;
    // go(route);
    // The above direct reflect can be brittle; use a try-catch with extension access:
    // If this fails, Navigator fallback below will run.
    // The expression below intentionally calls a non-existent method when go_router
    // isn't in the app; it's caught in the catch block.
    // ignore: undefined_method
    // context.go(route);
    // Because static analysis blocks calling undefined methods, wrap in dynamic:
    (context as dynamic).go(route);
    return;
  } catch (_) {/* fall through */}

  // Fallback to Navigator named routes
  try {
    context.go(route);       // or context.push(route) if you want to keep a back stack
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Route not found: $route')),
    );
  }
}

/// ---------- Role -> visible tile labels ----------
const Map<String, Set<String>> kTilesByRole = {
  'field_incharge': {
    'Farmer Network',
    'Farmer Registration',
    'Field Observations',
    'Inputs Details',
    'Activity Schedule',
    'Daily logs & Schedule',
    'Diagnostics',
    'Field Diagnostics',
  },
  // 'cluster_incharge': {...},
  // 'territory_incharge': {...},
  // 'manager': {...},
};

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final theme = Theme.of(context);

    final isCIC = auth.role?.toLowerCase() == Roles.clusterIncharge;

    final isFIC = auth.role?.toLowerCase() == Roles.fieldIncharge;

    // near the top of build()
    //final isCIC = auth.isClusterIncharge == true ||
        //auth.currentUserRole == UserRole.cluster_incharge;


    // ---------- Your existing tiles (labels, icons, colors, routes) ----------
    final tiles = <_DashTile>[

 // =====================
// Field Incharge tiles
// =====================


      if (isFIC) ...[

        _DashTile(
          label: 'Farmer Network',
          color: const Color(0xFFDDEBD9),
          icon: Icons.hub,
          route: '/farmers/network',
        ),
        _DashTile(
          label: 'Farmer Registration',
          color: const Color(0xFFDCE7FF),
          icon: Icons.person_add_alt_1,
          route: '/farmers/registration',
        ),

        _DashTile(
          label: 'Activity Schedule',
          color: const Color(0xFFF7E1CC),
          icon: Icons.science_outlined,
          route: '/activity/schedule',
        ),

        _DashTile(
          label: 'Daily logs & Schedule',
          color: const Color(0xFFE9ECEF),
          icon: Icons.access_time,
          route: '/daily-logs',
        ),

      ],


// =====================
// Normal tiles
// =====================

     /* _DashTile(
        label: 'Farmer Network',
        color: const Color(0xFFDDEBD9),
        icon: Icons.hub,
        route: '/farmers/network',
      ),
      _DashTile(
        label: 'Farmer Registration',
        color: const Color(0xFFDCE7FF),
        icon: Icons.person_add_alt_1,
        route: '/farmers/registration',
      ),*/
      _DashTile(
        label: 'Field Observations',
        color: const Color(0xFFF5EDC7),
        icon: Icons.edit_note,
        route: '/field/observations',
      ),
      _DashTile(
        label: 'Inputs Details',
        color: const Color(0xFFE7DBFF),
        icon: Icons.inventory_2_outlined,
        route: '/inputs/supply',
      ),
      /*_DashTile(
        label: 'Daily logs & Schedule',
        color: const Color(0xFFE9ECEF),
        icon: Icons.access_time,
        route: '/daily/logs',
      ),*/
      _DashTile(
        label: 'Diagnostics',
        color: const Color(0xFFFCE0E0),
        icon: Icons.health_and_safety_outlined,
        route: '/diagnostics',
      ),
      _DashTile(
        label: 'Field Diagnostics',
        color: const Color(0xFFE0F2F1),
        icon: Icons.biotech_outlined,
        route: '/field/diagnostics',
      ),


// =====================
// Cluster Incharge tiles
// Following cards applicable Only for Cluster Incharge
// =====================

      if (isCIC) ...[

        _DashTile(
          label: 'Farmers Network Details',
          color: const Color(0xFFE0F2F1),
          icon: Icons.hub_outlined,
          route: '/cic/farmers/networks',
        ),
        _DashTile(
          label: 'Farmers Registration Details',
          color: const Color(0xFFE0F2F1),
          icon: Icons.app_registration_outlined,
          route: '/cic/farmers/registrations',
        ),
        _DashTile(
          label: 'Field Incharge Details',
          color: const Color(0xFFE0F2F1),
          icon: Icons.badge_outlined,
          // if your _DashTile uses 'title' instead of 'label', switch the prop name
          route: '/cic/field-incharges',
        ),
        _DashTile(
          label: 'Activity Schedule Details',
          color: const Color(0xFFF7E1CC),
          icon: Icons.science_outlined,
          route: '/cluster/activity-schedule/',
        ),
        _DashTile(
          label: 'Field Incharge Daily Logs Details',
          color: const Color(0xFFFE9CEF),
          icon: Icons.science_outlined,
          route: '/cluster-daily-logs',
        ),
        _DashTile(
          label: 'Daily logs & Schedule',
          color: const Color(0xFFE9ECEF),
          icon: Icons.access_time,
          route: '/cluster/daily-logs',
        ),

      ]
    ];




    // ---------- Role filtering with safety-net (never blank) ----------
    final allowedLabels = auth.isSuper
        ? tiles.map((t) => t.label).toSet()
        : (kTilesByRole[auth.role] ?? const <String>{});

    final filtered = tiles.where((t) => allowedLabels.contains(t.label)).toList();
    final visibleTiles = filtered.isEmpty ? tiles : filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) {
                // If you use go_router, this will be caught by AuthGate; if not,
                try {
                  (context as dynamic).go('/login');
                } catch (_) {
                  context.go('/login');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Test Daily Logs route',
            onPressed: () {
              const fiUid = 'mnfaPUW34OVcB9rbV78eeDjY83B2'; // test uid
              final dest = '/cluster-daily-logs?fiUid=$fiUid';
              debugPrint('[AppBar] navigating to $dest');
              context.push(dest);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------- Top header buttons (kept simple; keep your styling if you had fancier chips) ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _HeaderButton(
                  label: 'Home',
                  icon: Icons.home_filled,
                  onTap: () => _nav(context, '/'),
                ),
                _HeaderButton(
                  label: 'Communication',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => _nav(context, '/communication'),
                ),
                _HeaderButton(
                  label: 'Setting',
                  icon: Icons.settings_outlined,
                  onTap: () => _nav(context, '/settings'),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.05,
              children: [
                for (final t in visibleTiles) _DashCard(tile: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String? route;
  final VoidCallback? onTap;

  const _DashTile({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.route,
    this.onTap,
  }) : assert(onTap != null || route != null,
  'Provide either onTap or route for _DashTile');



  @override
  Widget build(BuildContext context) {
    debugPrint('[DashTile] build "$label" ${identityHashCode(this)}');

    return Material( // ensures splash & hit testing
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (onTap != null) {
            debugPrint('[DashTile] using custom onTap for "$label"');
            onTap!();
          } else {
            debugPrint('[DashTile] default tap -> $route');
            context.push(route!);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}


class _DashCard extends StatelessWidget {
  final _DashTile tile;
  const _DashCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        if (tile.onTap != null) {
          debugPrint('[DashTile] custom onTap -> ${tile.label}');
          tile.onTap!.call();
          return;
        }
        if (tile.route != null && tile.route!.isNotEmpty) {
          debugPrint('[DashTile] default tap -> ${tile.route}');
          _nav(context, tile.route!); // safe to '!' now
          return;
        }
        debugPrint('[DashTile] no onTap or route for ${tile.label}');
      },
      child: Ink(
        decoration: BoxDecoration(
          color: tile.color,
          borderRadius: BorderRadius.circular(24),
        ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tile.icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tile.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onPrimary,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
