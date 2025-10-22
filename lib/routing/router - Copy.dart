import 'package:app_clean/features/cluster/cluster_input_supply_details_screen.dart';
import 'package:app_clean/features/cluster/cluster_input_supply_screen.dart';
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
import '../features/cluster/cluster_farmer_network_list_detail_screen.dart';
import '../features/cluster/cluster_farmer_network_list_screen.dart';
import '../features/cluster/cluster_farmer_registrations_list_details_screen.dart';
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
import '../features/manager/manager_activity_schedule_screen.dart';
import '../features/manager/manager_analytics_screen.dart';
import '../features/manager/manager_daily_logs_screen.dart';
import '../features/manager/manager_dashboard_screen.dart';
import '../features/manager/manager_farmer_network_screen.dart';
import '../features/manager/manager_farmer_registrations_screen.dart';
import '../features/manager/manager_field_diagnostics_screen.dart';
import '../features/manager/manager_field_incharges_screen.dart';
import '../features/manager/manager_field_observations_screen.dart';
import '../features/manager/manager_input_activities_screen.dart';
import '../features/schedule/activity_schedule_details_screen.dart';
import '../features/schedule/activity_schedule_screen.dart';
import '../features/schedule/daily_logs_details_screen.dart';
import '../features/schedule/daily_logs_list_screen.dart';
import '../features/schedule/daily_logs_screen.dart';
import '../features/settings/settings_screen.dart';
import '../theme/brand_theme.dart';

import 'package:app_clean/features/cluster/field_incharge_list_screen.dart';
import 'package:app_clean/features/cluster/cluster_farmer_registrations_list_screen.dart';


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
            allowedRoles: kFieldAndUp,
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

        // CIC: Farmer Networks details list
        GoRoute(
          path: '/cic/field-incharges/farmer-networks',
          name: 'ci.field_incharges.farmer-networks',
          builder: (ctx, st) => const ClusterFarmerNetworkListScreen(),
        ),
        GoRoute(
          path: '/cic/field-incharges/farmer-networks/:uid',
          name: 'ci.field_incharges.farmer-networks.detail',
          builder: (_, st) => ClusterFarmerNetworkDetailsScreen(
            uid: st.pathParameters['uid']!,
          ),
        ),

        // CIC: Farmer registrations details list
        GoRoute(
          path: '/cic/field-incharges/farmer-registrations',
          name: 'ci.field_incharges.farmer-registrations',
          builder: (ctx, st) => const ClusterFarmerRegistrationsListScreen(),
        ),


        GoRoute(
          path: '/cic/field-incharges/farmer-registrations/:uid',
          name: 'ci.field_incharges.farmer-registrations.detail',
          builder: (_, st) => ClusterFarmerRegistrationsDetailsScreen(
            uid: st.pathParameters['uid']!,
          ),
        ),

        //Cluster incharge Inputs details
        GoRoute(
          path: '/cic/field-incharges/inputs-details',
          name: 'ci.field_incharges.inputs-details',
          builder: (_, __) => const ClusterInputSupplyListScreen(),
        ),

        // Field Incharge Inputs Details - detail page
        GoRoute(
          path: '/cic/field-incharges/inputs-details/:uid',
          name: 'ci.field_incharges.inputs-details.detail',
          builder: (_, st) => ClusterInputSupplyDetailsScreen(
            uid: st.pathParameters['uid']!,
          ),
        ),


        // CIC: Field Incharge details list
        GoRoute(
          path: '/cic/field-incharges',
          name: 'ci.field_incharges',
          builder: (ctx, st) => const FieldInchargesListScreen(),
        ),

        // 3️⃣ Generic FI detail route (must be last)
        GoRoute(
          path: '/cic/field-incharges/:uid',
          name: 'cic.fi.detail',
          builder: (_, st) => FieldInchargeDetailScreen(
            uid: st.pathParameters['uid']!,
          ),
        ),



        //Cluster incharge Activity schedule details
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

        GoRoute(
          path: '/cluster/daily-logs',
          name: 'cic.daily.logs.form',
          builder: (_, __) => const DailyLogsScreen(),
        ),

        GoRoute(
          path: '/cluster/daily-logs/list',
          name: 'cic.daily.logs.list',
          builder: (_, __) => const DailyLogsListScreen(),
        ),

        GoRoute(
          path: '/cluster/daily-logs/list/:docId',
          name: 'cic.daily.log.detail',
          builder: (ctx, st) => DailyLogsDetailsScreen(
            docId: st.pathParameters['docId']!,
          ),
        ),



        GoRoute(
          path: '/cluster-daily-logs',
          name: 'ci.daily.logs',
          builder: (_, __) => const ClusterDailyLogsListScreen(),
        ),


        //Manager Dashboard
        GoRoute(
          path: '/manager-dashboard',
          builder: (context, state) => const ManagerDashboardScreen(),
        ),

        // Manager Dashboard (optional, could keep as landing page)
        GoRoute(
          path: '/manager-dashboard',
          builder: (context, state) => const ManagerDashboardScreen(),
        ),

        // Manager - Farmer Network
        GoRoute(
          path: '/manager-farmer-network',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Farmer Network',
            collectionName: 'farmers_network',
            summaryFields: ['fieldInchargeUid'], // counts per FI maybe
            listFields: ['networkName', 'fieldInchargeUid'],
            chartType: ChartType.bar,
            color: Colors.blue,
          ),
        ),


        // Manager - Farmer Registrations
        GoRoute(
          path: '/manager-farmer-registrations',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Farmer Registrations',
            collectionName: 'farmer_registrations',
            summaryFields: ['fiUid'], // count registrations per FI
            listFields: ['farmerName', 'fiUid'],
            chartType: ChartType.line,
            color: Colors.green,
          ),
        ),

        // Manager - Field Incharges
        GoRoute(
          path: '/manager-field-incharge-details',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Field Incharge Details',
            collectionName: 'field_incharges',
            summaryFields: ['orgPathUids'], // total FIs
            listFields: ['name', 'email'],
            chartType: ChartType.pie,
            color: Colors.orange,
          ),
        ),

        // Manager - Daily Logs
        GoRoute(
          path: '/manager-field-incharge-daily-logs',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Field Incharge Daily Logs',
            collectionName: 'daily_logs',
            summaryFields: ['ownerUid'], // logs submitted per FI
            listFields: ['ownerUid', 'notes'],
            chartType: ChartType.bar,
            color: Colors.purple,
          ),
        ),

        // Manager - Activity Schedule
        GoRoute(
          path: '/manager-activity-schedule',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Activity Schedule',
            collectionName: 'activity_schedule',
            summaryFields: ['fiUid'], // total activities per FI
            listFields: ['activityName', 'fiUid', 'scheduledDate'],
            chartType: ChartType.line,
            color: Colors.teal,
          ),
        ),

        // Manager - Input Activities
        GoRoute(
          path: '/manager-input-activity',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Input Activity',
            collectionName: 'input_supplies',
            summaryFields: ['createdBy'], // total inputs distributed per FI
            listFields: ['inputName', 'quantity', 'createdBy'],
            chartType: ChartType.bar,
            color: Colors.red,
          ),
        ),

        // Manager - Field Observations
        GoRoute(
          path: '/manager-field-observations',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Field Observations',
            collectionName: 'field_observations',
            summaryFields: ['fiUid'], // observations submitted per FI
            listFields: ['fieldName', 'notes', 'fiUid'],
            chartType: ChartType.line,
            color: Colors.brown,
          ),
        ),

        // Manager - Field Diagnostics
        GoRoute(
          path: '/manager-field-diagnostics',
          builder: (context, state) => const ManagerAnalyticsScreen(
            title: 'Manager - Field Diagnostics',
            collectionName: 'field_diagnostics',
            summaryFields: ['fiUid'], // diagnostics submitted per FI
            listFields: ['fieldName', 'issue', 'fiUid'],
            chartType: ChartType.bar,
            color: Colors.indigo,
          ),
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

