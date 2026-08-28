/// Every destination in the field application.
///
/// Slice 1 implements [splash], [login], [role], [home] and [profile]. The
/// remainder are routed and reachable, but render an explicit
/// "coming in the next development slice" page - they are not simulated.
enum AppRoute {
  splash('/', 'Splash'),
  login('/login', 'Sign in'),
  role('/role', 'Role'),
  home('/home', 'Home'),
  incidents('/incidents', 'Incidents'),
  victims('/victims', 'Victims'),
  sos('/sos', 'SOS'),
  hazards('/hazards', 'Hazards'),
  tasks('/tasks', 'Tasks'),
  map('/map', 'Map'),
  profile('/profile', 'Profile');

  const AppRoute(this.path, this.title);

  final String path;
  final String title;
}
