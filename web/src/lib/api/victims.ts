import { apiRequest } from "./client";

/** Severity order. The array order is the sort order the backend applies. */
export const TRIAGE_CATEGORIES = ["CRITICAL", "URGENT", "MODERATE", "STABLE"] as const;

export type TriageCategory = (typeof TRIAGE_CATEGORIES)[number];

export const VICTIM_STATUSES = [
  "REGISTERED",
  "UNDER_TREATMENT",
  "AWAITING_EVACUATION",
  "EVACUATED",
  "DECEASED",
] as const;

export type VictimStatus = (typeof VICTIM_STATUSES)[number];

export const STATUS_LABELS: Record<VictimStatus, string> = {
  REGISTERED: "Registered",
  UNDER_TREATMENT: "Under treatment",
  AWAITING_EVACUATION: "Awaiting evacuation",
  EVACUATED: "Evacuated",
  DECEASED: "Deceased",
};

export interface Victim {
  id: string;
  temporary_id: string;
  name: string | null;
  age: number | null;
  age_group: string;
  gender: string;
  medical_condition: string | null;
  injury_type: string | null;
  triage_category: TriageCategory;
  priority: number;
  assistance_required: string | null;
  status: VictimStatus;
  latitude: number | null;
  longitude: number | null;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface TriageCounts {
  critical: number;
  urgent: number;
  moderate: number;
  stable: number;
}

export interface VictimBoard {
  total: number;
  open_cases: number;
  evacuated: number;
  by_triage: TriageCounts;
}

export interface VictimPage {
  items: Victim[];
  board: VictimBoard;
  total: number;
}

export interface VictimQuery {
  search?: string;
  triage?: TriageCategory | null;
  status?: VictimStatus | null;
}

export function fetchVictims(
  token: string,
  query: VictimQuery = {},
  signal?: AbortSignal,
): Promise<VictimPage> {
  const params = new URLSearchParams();
  if (query.search?.trim()) params.set("search", query.search.trim());
  if (query.triage) params.set("triage", query.triage);
  if (query.status) params.set("status", query.status);

  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<VictimPage>(`/victims${suffix}`, { token, signal });
}

export function fetchVictimBoard(token: string, signal?: AbortSignal): Promise<VictimBoard> {
  return apiRequest<VictimBoard>("/victims/board", { token, signal });
}
