/// Every destination in the field application.
///
/// Slices 1 and 2 implement [splash], [login], [role], [home], [profile] and
/// the victim module. The remainder are routed and reachable, but render an
/// explicit "coming in the next development slice" page - they are not
/// simulated.
enum AppRoute {
  splash('/', 'Splash'),
  login('/login', 'Sign in'),
  role('/role', 'Role'),
  home('/home', 'Home'),
  incidents('/incidents', 'Incidents'),
  victims('/victims', 'Victims'),
  victimRegister('/victims/new', 'Register Victim'),
  victimDetail('/victims/:id', 'Victim'),
  victimEdit('/victims/:id/edit', 'Update Victim'),
  sos('/sos', 'SOS'),
  hazards('/hazards', 'Hazards'),
  tasks('/tasks', 'Tasks'),
  map('/map', 'Map'),
  profile('/profile', 'Profile');

  const AppRoute(this.path, this.title);

  /// Template path. Entries carrying a `:id` segment are matched by GoRouter
  /// rather than compared literally, so use the builders below to navigate.
  final String path;

  final String title;

  static String victimDetailPath(String id) => '/victims/$id';

  static String victimEditPath(String id) => '/victims/$id/edit';
}
