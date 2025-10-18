import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/roles.dart';
import '../core/services/auth_service.dart';
import '../core/widgets/role_guard.dart';
import '../features/auth/login_screen.dart';
import '../features/cluster/cluster_activity_schedule_detail_screen.dart' hide AuthService;
import '../features/cluster/cluster_activity_schedule_list_screen.dart';
import '../features/cluster/cluster_daily_logs_details_screen.dart';
import '../features/cluster/cluster_daily_logs_list_screen.dart';
import '../features/cluster/fied_incharge_list_details_screen.dart';
import '../features/communication/communication_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

import 'package:app_clean/features/farmers/farmer_network_screen.dart';

import 'package:app_clean/features/farmers/registration_screen.dart';

import '../features/diagnostics/diagnostics_screen.dart';
import '../features/diagnostics/field_diagnostics_details_screen.dart';
import '../features/diagnostics/field_diagnostics_screen.dart';
import '../features/farmers/farmers_screen.dart';
import '../features/fields/field_observations_list_screen.dart';
import '../features/fields/field_observations_screen.dart';
import '../features/inputs/input_supply_screen.dart';
import '../features/inputs/inputs_details_screen.dart';
import '../features/schedule/activity_schedule_details_screen.dart';
import '../features/schedule/activity_schedule_screen.dart';
import '../features/schedule/daily_logs_details_screen.dart';
import '../features/schedule/daily_logs_list_screen.dart';
import '../features/schedule/daily_logs_screen.dart';
import '../features/settings/settings_screen.dart';
import '../theme/brand_theme.dart';

import 'package:app_clean/features/cluster/field_incharge_list_screen.dart';
import 'package:app_clean/features/cluster/cluster_farmers_network_list_screen.dart';
import 'package:app_clean/features/cluster/cluster_farmer_registrations_list_screen.dart';

import '../features/cluster/farmer_network_detail_screen.dart';

/// Root navigator key (handy if you later add shell routes)
final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();


class LoggingObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('[Nav] push -> ${route.settings.name} (${route.settings.arguments})');
  }
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint('[Nav] replace -> ${newRoute?.settings.name}');
  }
  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('[Nav] pop -> ${route.settings.name}');
  }
}

/// A widget that builds MaterialApp.router with a GoRouter that
/// reacts to AuthService (login/logout) and knows all app paths.
class AppRouter extends StatelessWidget {
  AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final GoRouter appRouter = GoRouter(
      debugLogDiagnostics: true,
      navigatorKey: rootNavKey,
      initialLocation: '/login',                         // we'll redirect below anyway
      refreshListenable: auth,                      // rebuild on login/logout
      redirect: (ctx, state) {
        // get auth from Provider in the redirect's own BuildContext
        final a = ctx.read<AuthService>();

        // decide logged-in status using what you already expose
        // (pick whichever your service supports)
        final bool loggedIn =
            (a.isLoggedIn == true) || (a.currentUser != null);

        final bool goingToLogin = state.matchedLocation == '/login';

        if (!loggedIn) {
          // not logged in -> always go to /login (unless already there)
          return goingToLogin ? null : '/login';
        }

        // logged in -> don't allow staying on /login
        if (goingToLogin) return '/'; // or your post-login route

        return null; // no redirect
      },
      observers: [LoggingObserver()],     // 👈 add this
      routes: [
        GoRoute(
          path: '/login',
          builder: (ctx, s) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (ctx, s) => const DashboardScreen(),
        ),

        // === Feature tiles (make these match what your tiles use) ===
        GoRoute(
        path: '/farmers/network',
          builder: (_, __) => RoleGuard(
            allowedRoles: const {
              'field_incharge'
            },
            //allowedRoles: kFieldAndUp,
            child: const FarmerNetworkScreen(),
          ),
        ),
        GoRoute(
          path: '/farmers/registration',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const FarmerRegistrationScreen(),
          ),
        ),
        GoRoute(
          path: '/field/observations',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const FieldObservationsScreen(),
          ),
        ),
        GoRoute(
          path: '/inputs/supply',
          name: 'fi.inputs.supply.list',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const InputSupplyScreen(),
          ),
        ),
        GoRoute(
          path: '/activity/schedule',
          name: 'fi.activity.schedule.list',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const ActivityScheduleScreen(),
          ),
        ),
        GoRoute(
          path: '/diagnostics',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const DiagnosticsScreen(),
          ),
        ),
        // LIST
        GoRoute(
          path: '/daily-logs',
          name: 'daily.logs.form',                 // ← form
          builder: (_, __) => const DailyLogsScreen(),
          routes: [
            GoRoute(
              path: 'list',
              name: 'fi.daily.logs.list',             // ← list
              builder: (_, __) => const DailyLogsListScreen(),
              routes: [
                GoRoute(
                  path: ':docId',
                  name: 'fi.daily.log.detail',        // ← detail
                  builder: (ctx, st) => DailyLogsDetailsScreen(
                    docId: st.pathParameters['docId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        // LIST
        GoRoute(
          path: '/cluster/daily-logs',
          name: 'cic.daily.logs.form',                 // ← form
          builder: (_, __) => const DailyLogsScreen(),
          routes: [
            GoRoute(
              path: 'list',
              name: 'cic.daily.logs.list',             // ← list
              builder: (_, __) => const DailyLogsListScreen(),
              routes: [
                GoRoute(
                  path: ':docId',
                  name: 'cic.daily.log.detail',        // ← detail
                  builder: (ctx, st) => DailyLogsDetailsScreen(
                    docId: st.pathParameters['docId']!,
                  ),
                ),
              ],
            ),
          ],
        ),

        GoRoute(
          path: '/field/diagnostics',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const FieldDiagnosticsScreen(),
          ),
        ),
        GoRoute(
          path: '/communication',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: const CommunicationScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp, // <-- use the same constant you used for the form
            child: const SettingsScreen(),
          ),
        ),

        //Saved OR details ones
        GoRoute(
          path: '/farmers/farmers/saved',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp, // <-- use the same constant you used for the form
            child: const FarmersScreen(),
          ),
        ),
        GoRoute(
          path: '/farmers/network/saved',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp, // <-- use the same constant you used for the form
            child: const FarmerNetworkScreen(),
          ),
        ),
        GoRoute(
          path: '/fields/observations/saved',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp, // <-- use the same constant you used for the form
            child: const FieldObservationsListScreen(),
          ),
        ),
        GoRoute(
          path: '/inputs/inputs_details/saved/:docId',
          name: 'fi.inputs.detail',
          builder: (_, st) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: InputsDetailsScreen(
              docId: st.pathParameters['docId']!,   // ✅
            ),
          ),
        ),
        GoRoute(
          path: '/schedule/activity/schedule/saved/:docId',
          name: 'fi.activity.schedule.detail',
          builder: (_, st) => RoleGuard(
            allowedRoles: kFieldAndUp,
            child: ActivityScheduleDetailsScreen(
              docId: st.pathParameters['docId']!,   // ✅
            ),
          ),
        ),
        GoRoute(
          path: '/fields/diagnostics/saved',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp, // <-- use the same constant you used for the form
            child: const DiagnosticsScreen(),
          ),
        ),
        GoRoute(
          path: '/fields/field/diagnostics/saved',
          builder: (_, __) => RoleGuard(
            allowedRoles: kFieldAndUp, // <-- use the same constant you used for the form
            child: const FieldDiagnosticsDetailsScreen(),
          ),
        ),

        // CIC: Field Incharge details list
        GoRoute(
          path: '/cic/field-incharges',
          name: 'cic_field_incharges',
          builder: (ctx, st) => const FieldInchargesScreen(),
        ),

// CIC: Farmers Network (FN_...) created under my orgPath
        GoRoute(
          path: '/cic/farmers/networks',
          name: 'cic_farmers_networks',
          builder: (ctx, st) => const ClusterFarmersNetworkListScreen(),
        ),

// CIC: Farmer Registrations (FR_...) created under my orgPath
        /*GoRoute(
          path: '/cic/farmers/registrations',
          name: 'cic_farmers_registrations',
          builder: (ctx, st) => const ClusterFarmerRegistrationsListScreen(),
        ),*/

        GoRoute(
          path: '/cic/field-incharges',
          name: 'cic-fi-list',
          builder: (ctx, state) => const FieldInchargesScreen(),
        ),

        GoRoute(
          path: '/cic/field-incharge/:uid',
          name: 'cic-fi-detail',
          builder: (ctx, state) => FieldInchargeDetailScreen(uid: state.pathParameters['uid']!),
        ),

        GoRoute(
          path: '/cic/farmers/registrations',
          builder: (ctx, st) => const ClusterFarmerRegistrationsListScreen(),
          routes: [
            GoRoute(
              path: ':docId',
              name: 'fr.detail',
              builder: (ctx, st) => const FarmerRegistrationScreen(),
            ),
          ],
        ),

        // CIC: Activity Schedule (detail)
        // router.dart
        GoRoute(
          path: '/cluster/activity-schedule',
          name: 'ci.activity.schedule.auto',
          builder: (_, __) => const ClusterActivityScheduleListScreen(),
        ),

        GoRoute(
          path: '/cluster/activity-schedule/:docId',
          name: 'ci.activity.schedule.detail',
          builder: (_, st) => ClusterActivityScheduleDetailScreen(
            docId: st.pathParameters['docId']!,
          ),
        ),


        //Cluster Daily logs for Field Incharges
        // LIST
        // List (no seed) – CI opens list and picks an FI



// List (seeded with a specific FI)
        // --- CI list (single-page with dropdowns) ---
        GoRoute(
          path: '/cluster-daily-logs',
          name: 'ci.daily.logs',
          builder: (_, __) => const ClusterDailyLogsListScreen(),
        ),

// --- CI seeded + DETAIL that reuses the same screen but passes userUid = fiId ---
        GoRoute(
          path: '/cluster-daily-logs/:fiId/:docId',
          name: 'ci.daily.log.detail',
          builder: (ctx, st) => ClusterDailyLogsDetailsScreen(
            fiId: st.pathParameters['fiId']!,
            docId: st.pathParameters['docId']!,
          ),
        ),




        //Cluster Farmer network
        GoRoute(
          path: '/cic/farmers/network/:docId',
          name: 'cic.network.detail',
          builder: (ctx, st) => FarmerNetworkDetailScreen(
            docId: st.pathParameters['docId']!,
          ),
        ),




      ],
      errorBuilder: (ctx, state) => _NotFound(state.error?.toString()),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MaizeMate',
      theme: buildBrandTheme(),
      routerConfig: appRouter,      // <-- use appRouter here
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Page Not Found\n\n${message ?? ''}',
            textAlign: TextAlign.center),
      ),
    );
  }
}

