import { apiRequest } from "./client";

export const DISASTER_TYPES = [
  "EARTHQUAKE",
  "FLOOD",
  "FIRE",
  "LANDSLIDE",
  "CYCLONE",
  "INDUSTRIAL_ACCIDENT",
  "BUILDING_COLLAPSE",
  "OTHER",
] as const;

export type DisasterType = (typeof DISASTER_TYPES)[number];

export const INCIDENT_STATUSES = ["ACTIVE", "PAUSED", "RESOLVED"] as const;
export type IncidentStatus = (typeof INCIDENT_STATUSES)[number];

export const INCIDENT_STATUS_LABELS: Record<IncidentStatus, string> = {
  ACTIVE: "Active",
  PAUSED: "Paused",
  RESOLVED: "Resolved",
};

export interface Incident {
  id: string;
  incident_code: string;
  title: string;
  disaster_type: DisasterType;
  description: string | null;
  status: IncidentStatus;
  assigned_zone: string | null;
  latitude: number | null;
  longitude: number | null;
  created_by: string;
  last_modified_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface IncidentBoard {
  total: number;
  by_status: { active: number; paused: number; resolved: number };
}

export interface IncidentPage {
  items: Incident[];
  total: number;
}

export interface IncidentQuery {
  search?: string;
  disaster_type?: DisasterType | null;
  status?: IncidentStatus | null;
}

export function fetchIncidents(
  token: string,
  query: IncidentQuery = {},
  signal?: AbortSignal,
): Promise<IncidentPage> {
  const params = new URLSearchParams();
  if (query.search?.trim()) params.set("search", query.search.trim());
  if (query.disaster_type) params.set("disaster_type", query.disaster_type);
  if (query.status) params.set("status", query.status);
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<IncidentPage>(`/incidents${suffix}`, { token, signal });
}

export function fetchIncidentBoard(token: string, signal?: AbortSignal): Promise<IncidentBoard> {
  return apiRequest<IncidentBoard>("/incidents/board", { token, signal });
}
