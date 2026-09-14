import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/role_screen.dart';
import '../../features/hazards/presentation/hazard_detail_screen.dart';
import '../../features/hazards/presentation/hazard_edit_screen.dart';
import '../../features/hazards/presentation/hazard_report_screen.dart';
import '../../features/hazards/presentation/hazards_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/incidents/presentation/incident_declare_screen.dart';
import '../../features/incidents/presentation/incident_detail_screen.dart';
import '../../features/incidents/presentation/incident_edit_screen.dart';
import '../../features/incidents/presentation/incidents_screen.dart';
import '../../features/placeholder/placeholder_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/sos/presentation/sos_detail_screen.dart';
import '../../features/sos/presentation/sos_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/sync/presentation/sync_center_screen.dart';
import '../../features/sync/presentation/sync_conflict_detail_screen.dart';
import '../../features/sync/presentation/sync_conflict_list_screen.dart';
import '../../features/sync/presentation/sync_pending_screen.dart';
import '../../features/tasks/presentation/task_create_screen.dart';
import '../../features/tasks/presentation/task_detail_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/victims/presentation/victim_detail_screen.dart';
import '../../features/victims/presentation/victim_edit_screen.dart';
import '../../features/victims/presentation/victim_register_screen.dart';
import '../../features/victims/presentation/victims_screen.dart';
import '../../shared/widgets/main_shell.dart';
import 'app_routes.dart';

/// Routes that require a local session.
///
/// Paths that are not listed here at all still resolve to the login screen
/// while signed out - see [_redirect] - so a victim's detail page cannot be
/// reached by typing its URL.
const Set<AppRoute> _protectedRoutes = {
  AppRoute.role,
  AppRoute.home,
  AppRoute.incidents,
  AppRoute.incidentNew,
  AppRoute.victims,
  AppRoute.victimRegister,
  AppRoute.sos,
  AppRoute.hazards,
  AppRoute.hazardReport,
  AppRoute.tasks,
  AppRoute.taskNew,
  AppRoute.sync,
  AppRoute.syncPending,
  AppRoute.syncConflicts,
  AppRoute.syncConflictDetail,
  AppRoute.map,
  AppRoute.profile,
};

final routerProvider = Provider<GoRouter>((ref) {
  // GoRouter cannot watch a provider directly, so auth state is mirrored into
  // a Listenable it can refresh from.
  final authListenable = ValueNotifier<AuthState>(const AuthRestoring());
  ref.onDispose(authListenable.dispose);
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => authListenable.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: AppRoute.splash.path,
    refreshListenable: authListenable,
    redirect: (context, state) =>
        _redirect(authListenable.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.login.path,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.role.path,
        builder: (context, state) => const RoleScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppRoute.home.path,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoute.incidents.path,
            builder: (context, state) => const IncidentsScreen(),
          ),
          GoRoute(
            path: AppRoute.victims.path,
            builder: (context, state) => const VictimsScreen(),
          ),
          GoRoute(
            path: AppRoute.sos.path,
            builder: (context, state) => const SosScreen(),
          ),
          GoRoute(
            path: AppRoute.hazards.path,
            builder: (context, state) => const HazardsScreen(),
          ),
          GoRoute(
            path: AppRoute.tasks.path,
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: AppRoute.sync.path,
            builder: (context, state) => const SyncCenterScreen(),
          ),
          GoRoute(
            path: AppRoute.profile.path,
            builder: (context, state) => const ProfileScreen(),
          ),
          for (final route in _placeholderRoutes)
            GoRoute(
              path: route.route.path,
              builder: (context, state) => PlaceholderScreen(spec: route),
            ),
        ],
      ),

      // Outside the shell: a form and an individual record are full-screen
      // tasks that are pushed and popped, not navigation destinations. `new` is
      // declared before `:id` so it is not swallowed by the parameter.
      GoRoute(
        path: AppRoute.incidentNew.path,
        builder: (context, state) => const IncidentDeclareScreen(),
      ),
      GoRoute(
        path: AppRoute.incidentDetail.path,
        builder: (context, state) => IncidentDetailScreen(
          incidentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.incidentEdit.path,
        builder: (context, state) => IncidentEditScreen(
          incidentId: state.pathParameters['id']!,
        ),
      ),

      GoRoute(
        path: AppRoute.victimRegister.path,
        builder: (context, state) => const VictimRegisterScreen(),
      ),
      GoRoute(
        path: AppRoute.victimDetail.path,
        builder: (context, state) => VictimDetailScreen(
          victimId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.victimEdit.path,
        builder: (context, state) => VictimEditScreen(
          victimId: state.pathParameters['id']!,
        ),
      ),

      GoRoute(
        path: AppRoute.sosDetail.path,
        builder: (context, state) => SosDetailScreen(
          sosId: state.pathParameters['id']!,
        ),
      ),

      GoRoute(
        path: AppRoute.hazardReport.path,
        builder: (context, state) => const HazardReportScreen(),
      ),
      GoRoute(
        path: AppRoute.hazardDetail.path,
        builder: (context, state) => HazardDetailScreen(
          hazardId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.hazardEdit.path,
        builder: (context, state) => HazardEditScreen(
          hazardId: state.pathParameters['id']!,
        ),
      ),

      GoRoute(
        path: AppRoute.taskNew.path,
        builder: (context, state) => const TaskCreateScreen(),
      ),
      GoRoute(
        path: AppRoute.taskDetail.path,
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.syncPending.path,
        builder: (context, state) => const SyncPendingScreen(),
      ),
      GoRoute(
        path: AppRoute.syncConflicts.path,
        builder: (context, state) => const SyncConflictListScreen(),
      ),
      GoRoute(
        path: AppRoute.syncConflictDetail.path,
        builder: (context, state) => SyncConflictDetailScreen(
          conflictId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

/// Slice 1 navigation policy.
///
/// Returns the path to redirect to, or null to stay put.
@visibleForTesting
String? redirectForTest(AuthState auth, String location) =>
    _redirect(auth, location);

String? _redirect(AuthState auth, String location) {
  final target = _routeFor(location);

  // Session restoration is a real step, not a cosmetic delay: the local
  // database has to be opened before we know who is holding the device.
  if (auth.isRestoring) {
    return target == AppRoute.splash ? null : AppRoute.splash.path;
  }

  if (auth.isSignedIn) {
    final onEntryScreen =
        target == AppRoute.splash || target == AppRoute.login;
    return onEntryScreen ? AppRoute.home.path : null;
  }

  if (target != null && _protectedRoutes.contains(target)) {
    return AppRoute.login.path;
  }

  return target == AppRoute.login ? null : AppRoute.login.path;
}

AppRoute? _routeFor(String location) {
  for (final route in AppRoute.values) {
    if (route.path == location) return route;
  }
  return null;
}

/// The modules that are routed but not yet built.
const List<PlaceholderSpec> _placeholderRoutes = [
  PlaceholderSpec(
    route: AppRoute.map,
    slice: 5,
    summary: 'An offline map of the sector with responders, victims and hazards.',
    scope: [
      'Cached tiles for use with no network',
      'Own position and team positions',
      'Hazard zones and search progress',
    ],
  ),
];
