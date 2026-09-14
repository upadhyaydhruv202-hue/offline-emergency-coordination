import { apiRequest } from "./client";

export interface CommandKpis {
  active_incidents: number;
  critical_victims: number;
  active_responders: number;
  active_sos: number;
  open_hazards: number;
  blocked_roads: number;
  hospital_beds_remaining: number;
  pending_tasks: number;
  conflicts: number;
  pending_sync: number;
}

export interface CommandAlert {
  code: string;
  title: string;
  detail: string;
  severity: string;
  href: string;
}

export interface MapMarker {
  id: string;
  layer: string;
  label: string;
  latitude: number;
  longitude: number;
  status: string | null;
  severity: string | null;
  kind: string | null;
  subtitle: string | null;
}

export interface Presence {
  user_id: string;
  status: string;
  latitude: number | null;
  longitude: number | null;
  last_seen_at: string;
  device_id: string | null;
  assigned_incident_id: string | null;
  assigned_task: string | null;
  updated_at: string;
}

export interface OperationalResponder {
  id: string;
  email: string;
  full_name: string;
  role: string;
  is_active: boolean;
  created_at: string;
  presence: Presence | null;
}

export interface Facility {
  id: string;
  facility_code: string;
  kind: "HOSPITAL" | "SHELTER" | "RESOURCE_CACHE";
  name: string;
  status: string;
  incident_id: string | null;
  latitude: number | null;
  longitude: number | null;
  capacity_total: number;
  occupancy: number;
  remaining: number;
  emergency_available: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface AuditEvent {
  id: string;
  category: string;
  summary: string;
  severity: string;
  entity_type: string | null;
  entity_id: string | null;
  actor_id: string | null;
  occurred_at: string;
  created_at: string;
}

export interface SyncSummary {
  pending: number;
  in_flight: number;
  acknowledged: number;
  failed: number;
  conflicts: number;
  resolved_conflicts: number;
  distinct_devices: number;
  last_push_at: string | null;
  transport: string;
  note: string;
}

export interface CommandSnapshot {
  generated_at: string;
  kpis: CommandKpis;
  alerts: CommandAlert[];
  incidents: import("./incidents").Incident[];
  victims: import("./victims").Victim[];
  hazards: import("./hazards").Hazard[];
  sos: import("./sos").SosEvent[];
  tasks: import("./tasks").FieldTask[];
  responders: OperationalResponder[];
  facilities: Facility[];
  facility_board: {
    hospitals: number;
    shelters: number;
    resource_caches: number;
    hospital_beds_remaining: number;
    shelter_spaces_remaining: number;
  };
  activity: AuditEvent[];
  sync: SyncSummary;
  conflicts: import("./sync").SyncConflict[];
  markers: MapMarker[];
  layers: string[];
  facility_kinds: string[];
}

export function fetchCommandSnapshot(token: string, signal?: AbortSignal) {
  return apiRequest<CommandSnapshot>("/command/snapshot", { token, signal });
}

export function fetchFacilities(
  token: string,
  kind?: Facility["kind"],
  signal?: AbortSignal,
) {
  const suffix = kind ? `?kind=${kind}` : "";
  return apiRequest<{ items: Facility[]; total: number; board: CommandSnapshot["facility_board"] }>(
    `/facilities${suffix}`,
    { token, signal },
  );
}

export function fetchAuditEvents(token: string, signal?: AbortSignal) {
  return apiRequest<{ items: AuditEvent[]; total: number }>("/audit/events", { token, signal });
}
