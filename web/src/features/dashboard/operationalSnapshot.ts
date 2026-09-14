import type { StatusTone } from "../../components/ui/StatusPill";

export interface OperationalMetric {
  key: string;
  label: string;
  value: number;
  caption: string;
  tone: StatusTone;
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
  { area: "Role model", detail: "Five operational roles, write guards on facilities", state: "live", slice: "S5" },
  { area: "Victims & triage", detail: "Offline registration, four-category triage", state: "live", slice: "S2" },
  { area: "Field operations", detail: "Incidents, SOS, hazards, tasks", state: "live", slice: "S3" },
  { area: "Peer synchronisation", detail: "Simulated transport, CRDT merge, recorded conflicts", state: "live", slice: "S4" },
  { area: "Command centre COP", detail: "Dashboard, hospitals, shelters, activity feed", state: "live", slice: "S5" },
  { area: "Operational map", detail: "Leaflet layers over ingested coordinates", state: "live", slice: "S5" },
  { area: "Mesh transport", detail: "BLE, Wi-Fi Direct, LoRa carriage", state: "planned", slice: "S6" },
  { area: "Digital twin", detail: "Risk layers, routing, recommendations", state: "planned", slice: "S6" },
];
