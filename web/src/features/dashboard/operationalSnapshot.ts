import type { StatusTone } from "../../components/ui/StatusPill";

/**
 * Incident, responder, hazard, SOS and pending-sync counts are live from the API.
 * Mesh radios are still Slice 5. The sync figure is peer ingest / simulated merge,
 * not a live mesh.
 */

export interface OperationalMetric {
  key: string;
  label: string;
  value: number;
  caption: string;
  tone: StatusTone;
  /** Slice that will supply this figure for real. */
  source: string;
}

export const OPERATIONAL_METRICS: OperationalMetric[] = [];

export interface SliceCapability {
  area: string;
  detail: string;
  state: "live" | "planned";
  slice: string;
}

export const CAPABILITY_LEDGER: SliceCapability[] = [
  { area: "Authentication", detail: "JWT issue, refresh and role claim", state: "live", slice: "S1" },
  { area: "Role model", detail: "Five operational roles, route-level guards", state: "live", slice: "S1" },
  { area: "Local database", detail: "Drift/SQLite on the field device", state: "live", slice: "S1" },
  { area: "Connectivity", detail: "Online / degraded / offline detection", state: "live", slice: "S1" },
  { area: "Victims & triage", detail: "Offline registration, four-category triage", state: "live", slice: "S2" },
  { area: "Incidents", detail: "Local declaration, current operation, zones", state: "live", slice: "S3" },
  { area: "SOS & hazards", detail: "Local distress calls and hazard reports", state: "live", slice: "S3" },
  { area: "Tasks & responder status", detail: "Local lifecycle and check-in state", state: "live", slice: "S3" },
  { area: "Peer synchronisation", detail: "Simulated transport, CRDT merge, recorded conflicts", state: "live", slice: "S4" },
  { area: "Mesh transport", detail: "BLE, Wi-Fi Direct, LoRa carriage", state: "planned", slice: "S5" },
];
