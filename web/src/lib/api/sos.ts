import { apiRequest } from "./client";

export const SOS_PRIORITIES = ["CRITICAL", "HIGH", "MEDIUM"] as const;
export type SosPriority = (typeof SOS_PRIORITIES)[number];

export const SOS_STATUSES = ["CREATED", "ACKNOWLEDGED", "RESOLVED"] as const;
export type SosStatus = (typeof SOS_STATUSES)[number];

export const SOS_STATUS_LABELS: Record<SosStatus, string> = {
  CREATED: "Created",
  ACKNOWLEDGED: "Acknowledged",
  RESOLVED: "Resolved",
};

export interface SosEvent {
  id: string;
  sos_code: string;
  incident_id: string | null;
  latitude: number | null;
  longitude: number | null;
  priority: SosPriority;
  message: string | null;
  status: SosStatus;
  created_by: string;
  raised_at: string;
  created_at: string;
  updated_at: string;
}

export interface SosBoard {
  total: number;
  by_priority: { critical: number; high: number; medium: number };
  by_status: { created: number; acknowledged: number; resolved: number };
}

export interface SosEventPage {
  items: SosEvent[];
  total: number;
}

export interface SosQuery {
  priority?: SosPriority | null;
  status?: SosStatus | null;
}

export function fetchSosEvents(
  token: string,
  query: SosQuery = {},
  signal?: AbortSignal,
): Promise<SosEventPage> {
  const params = new URLSearchParams();
  if (query.priority) params.set("priority", query.priority);
  if (query.status) params.set("status", query.status);
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<SosEventPage>(`/sos${suffix}`, { token, signal });
}

export function fetchSosBoard(token: string, signal?: AbortSignal): Promise<SosBoard> {
  return apiRequest<SosBoard>("/sos/board", { token, signal });
}
