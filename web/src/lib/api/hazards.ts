import { apiRequest } from "./client";

export const HAZARD_TYPES = [
  "FLOOD",
  "FIRE",
  "SMOKE",
  "ROAD_BLOCKED",
  "BUILDING_DAMAGE",
  "BRIDGE_RISK",
  "LANDSLIDE",
  "ELECTRICAL_HAZARD",
  "CHEMICAL_HAZARD",
  "OTHER",
] as const;

export type HazardType = (typeof HAZARD_TYPES)[number];

export const HAZARD_SEVERITIES = ["CRITICAL", "HIGH", "MEDIUM", "LOW"] as const;
export type HazardSeverity = (typeof HAZARD_SEVERITIES)[number];

export const HAZARD_STATUSES = ["REPORTED", "VERIFIED", "RESOLVED"] as const;
export type HazardStatus = (typeof HAZARD_STATUSES)[number];

export const HAZARD_STATUS_LABELS: Record<HazardStatus, string> = {
  REPORTED: "Reported",
  VERIFIED: "Verified",
  RESOLVED: "Resolved",
};

export interface Hazard {
  id: string;
  hazard_code: string;
  incident_id: string | null;
  type: HazardType;
  severity: HazardSeverity;
  description: string | null;
  latitude: number | null;
  longitude: number | null;
  status: HazardStatus;
  reported_by: string;
  priority: number;
  observed_at: string;
  created_at: string;
  updated_at: string;
}

export interface HazardBoard {
  total: number;
  by_severity: { critical: number; high: number; medium: number; low: number };
  by_status: { reported: number; verified: number; resolved: number };
}

export interface HazardPage {
  items: Hazard[];
  total: number;
}

export interface HazardQuery {
  search?: string;
  type?: HazardType | null;
  severity?: HazardSeverity | null;
  status?: HazardStatus | null;
}

export function fetchHazards(
  token: string,
  query: HazardQuery = {},
  signal?: AbortSignal,
): Promise<HazardPage> {
  const params = new URLSearchParams();
  if (query.search?.trim()) params.set("search", query.search.trim());
  if (query.type) params.set("type", query.type);
  if (query.severity) params.set("severity", query.severity);
  if (query.status) params.set("status", query.status);
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<HazardPage>(`/hazards${suffix}`, { token, signal });
}

export function fetchHazardBoard(token: string, signal?: AbortSignal): Promise<HazardBoard> {
  return apiRequest<HazardBoard>("/hazards/board", { token, signal });
}
