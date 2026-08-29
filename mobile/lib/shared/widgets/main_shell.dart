import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/connectivity/connectivity_providers.dart';
import '../../features/connectivity/connectivity_status.dart';

/// Chrome shared by every in-session screen: title bar, connectivity readout,
/// drawer and bottom navigation.
class MainShell extends ConsumerWidget {
  const MainShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<AppRoute> _bottomBarRoutes = [
    AppRoute.home,
    AppRoute.victims,
    AppRoute.sos,
    AppRoute.map,
    AppRoute.profile,
  ];

  static const List<IconData> _bottomBarIcons = [
    Icons.dashboard_outlined,
    Icons.people_alt_outlined,
    Icons.emergency_outlined,
    Icons.map_outlined,
    Icons.person_outline,
  ];

  static const List<AppRoute> _drawerRoutes = [
    AppRoute.home,
    AppRoute.incidents,
    AppRoute.victims,
    AppRoute.sos,
    AppRoute.hazards,
    AppRoute.tasks,
    AppRoute.map,
    AppRoute.profile,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = _routeFor(location);
    final connectivity = ref.watch(connectivityStatusProvider);
    final status = connectivity.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentRoute?.title ?? 'Disaster Response'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _ConnectivityIndicator(status: status),
            ),
          ),
        ],
      ),
      drawer: _ShellDrawer(currentRoute: currentRoute),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(currentRoute),
        onDestinationSelected: (index) =>
            context.go(_bottomBarRoutes[index].path),
        destinations: [
          for (var i = 0; i < _bottomBarRoutes.length; i++)
            NavigationDestination(
              icon: Icon(_bottomBarIcons[i]),
              label: _bottomBarRoutes[i].title,
            ),
        ],
      ),
    );
  }

  int _selectedIndex(AppRoute? route) {
    final index = _bottomBarRoutes.indexOf(route ?? AppRoute.home);
    return index < 0 ? 0 : index;
  }

  static AppRoute? _routeFor(String location) {
    for (final route in AppRoute.values) {
      if (route.path == location) return route;
    }
    return null;
  }
}

class _ConnectivityIndicator extends StatelessWidget {
  const _ConnectivityIndicator({required this.status});

  final ConnectivityStatus? status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      ConnectivityStatus.online => (
          AppColors.nominal,
          Icons.cloud_done_outlined,
          'ONLINE',
        ),
      ConnectivityStatus.degraded => (
          AppColors.elevated,
          Icons.cloud_off_outlined,
          'DEGRADED',
        ),
      ConnectivityStatus.offline => (
          AppColors.critical,
          Icons.signal_cellular_off_outlined,
          'OFFLINE',
        ),
      null => (AppColors.ink500, Icons.sync, 'CHECKING'),
    };

    return Semantics(
      label: 'Connectivity $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellDrawer extends ConsumerWidget {
  const _ShellDrawer({required this.currentRoute});

  final AppRoute? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responder = ref.watch(authControllerProvider).responderOrNull;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar, color: AppColors.accentSoft, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'DRP FIELD',
                        style: TextStyle(
                          color: AppColors.ink100,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    responder?.fullName ?? 'No session',
                    style: const TextStyle(color: AppColors.ink200),
                  ),
                  Text(
                    responder?.role.label ?? '',
                    style: const TextStyle(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final route in MainShell._drawerRoutes)
                    ListTile(
                      dense: true,
                      selected: route == currentRoute,
                      selectedTileColor: AppColors.navy800,
                      title: Text(route.title),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(route.path);
                      },
                    ),
                ],
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'slice-2 · victims and triage',
                style: TextStyle(color: AppColors.ink500, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
