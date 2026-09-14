/// Every destination in the field application.
///
/// Slices 1 to 5 implement splash through sync plus the field map. Tiles are
/// not cached offline; pins always come from local SQLite.
enum AppRoute {
  splash('/', 'Splash'),
  login('/login', 'Sign in'),
  role('/role', 'Role'),
  home('/home', 'Home'),

  incidents('/incidents', 'Incidents'),
  incidentNew('/incidents/new', 'Declare Incident'),
  incidentDetail('/incidents/:id', 'Incident'),
  incidentEdit('/incidents/:id/edit', 'Update Incident'),

  victims('/victims', 'Victims'),
  victimRegister('/victims/new', 'Register Victim'),
  victimDetail('/victims/:id', 'Victim'),
  victimEdit('/victims/:id/edit', 'Update Victim'),

  sos('/sos', 'SOS'),
  sosDetail('/sos/:id', 'SOS Record'),

  hazards('/hazards', 'Hazards'),
  hazardReport('/hazards/new', 'Report Hazard'),
  hazardDetail('/hazards/:id', 'Hazard'),
  hazardEdit('/hazards/:id/edit', 'Update Hazard'),

  tasks('/tasks', 'Tasks'),
  taskNew('/tasks/new', 'New Task'),
  taskDetail('/tasks/:id', 'Task'),

  map('/map', 'Map'),
  sync('/sync', 'Sync'),
  syncPending('/sync/pending', 'Pending operations'),
  syncConflicts('/sync/conflicts', 'Conflicts'),
  syncConflictDetail('/sync/conflicts/:id', 'Conflict'),
  profile('/profile', 'Profile');

  const AppRoute(this.path, this.title);

  /// Template path. Entries carrying a `:id` segment are matched by GoRouter
  /// rather than compared literally, so use the builders below to navigate.
  final String path;

  final String title;

  static String victimDetailPath(String id) => '/victims/$id';

  static String victimEditPath(String id) => '/victims/$id/edit';

  static String incidentDetailPath(String id) => '/incidents/$id';

  static String incidentEditPath(String id) => '/incidents/$id/edit';

  static String sosDetailPath(String id) => '/sos/$id';

  static String hazardDetailPath(String id) => '/hazards/$id';

  static String hazardEditPath(String id) => '/hazards/$id/edit';

  static String taskDetailPath(String id) => '/tasks/$id';

  static String syncConflictDetailPath(String id) => '/sync/conflicts/$id';
}
