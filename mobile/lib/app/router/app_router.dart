import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/role_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/placeholder/placeholder_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/splash_screen.dart';
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
  AppRoute.victims,
  AppRoute.victimRegister,
  AppRoute.sos,
  AppRoute.hazards,
  AppRoute.tasks,
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
            path: AppRoute.victims.path,
            builder: (context, state) => const VictimsScreen(),
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

      // Outside the shell: a form and a casualty record are full-screen tasks
      // that are pushed and popped, not navigation destinations. `new` is
      // declared before `:id` so it is not swallowed by the parameter.
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
    route: AppRoute.incidents,
    slice: 3,
    summary:
        'Declaring an incident and scoping every record captured on this device to it.',
    scope: [
      'Incident declaration and lifecycle',
      'Sector assignment for this device',
      'Command structure and reporting lines',
    ],
  ),
  PlaceholderSpec(
    route: AppRoute.sos,
    slice: 3,
    summary: 'Raising and relaying distress beacons, including for other teams.',
    scope: [
      'One-touch responder SOS',
      'Relay of beacons received from nearby devices',
      'Acknowledgement and stand-down',
    ],
  ),
  PlaceholderSpec(
    route: AppRoute.hazards,
    slice: 3,
    summary: 'Recording hazards so other teams are warned before they arrive.',
    scope: [
      'Structural, gas, flood and electrical hazards',
      'Exclusion radius and expiry',
      'Propagation to nearby devices',
    ],
  ),
  PlaceholderSpec(
    route: AppRoute.tasks,
    slice: 4,
    summary: 'The work assigned to this responder, and its acknowledgement.',
    scope: [
      'Task assignment and acceptance',
      'Progress and completion evidence',
      'Reassignment when a team is redirected',
    ],
  ),
  PlaceholderSpec(
    route: AppRoute.map,
    slice: 3,
    summary: 'An offline map of the sector with responders, victims and hazards.',
    scope: [
      'Cached tiles for use with no network',
      'Own position and team positions',
      'Hazard zones and search progress',
    ],
  ),
];
