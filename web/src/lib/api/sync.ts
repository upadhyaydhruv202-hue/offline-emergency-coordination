import { apiRequest } from "./client";

export interface SyncStatus {
  pending: number;
  acknowledged: number;
  failed: number;
  conflicts: number;
  last_push_at: string | null;
  note: string;
}

export interface SyncConflict {
  id: string;
  entity_type: string;
  entity_id: string;
  resolution: string;
  winner_operation_id: string;
  loser_operation_id: string;
  reason: string;
  detected_at: string;
}

export interface SyncDemoScenario {
  kind: string;
  transport: string;
  incident: string;
  zone: string;
  entity: string;
  entity_id: string;
  device_a: { device_id: string; actor: string; type: string; severity: string };
  device_b: { device_id: string; actor: string; type: string; severity: string };
  resolution: string;
  winner_device: string;
  final_state: { type: string; severity: string };
  note: string;
}

export function fetchSyncStatus(token: string, signal?: AbortSignal) {
  return apiRequest<SyncStatus>("/sync/status", { token, signal });
}

export function fetchSyncConflicts(token: string, signal?: AbortSignal) {
  return apiRequest<SyncConflict[]>("/sync/conflicts", { token, signal });
}

export function fetchSyncDemoScenario(token: string, signal?: AbortSignal) {
  return apiRequest<SyncDemoScenario>("/sync/demo-scenario", { token, signal });
}
