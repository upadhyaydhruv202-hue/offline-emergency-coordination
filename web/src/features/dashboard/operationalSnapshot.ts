import type { StatusTone } from "../../components/ui/StatusPill";

/**
 * Hard-coded figures for the dashboard.
 *
 * This module is the single place fabricated numbers may live. Victim counts
 * have already left it: the Victims page reads them from the API. When the
 * incident, responder and synchronisation APIs land, the rest follows - no
 * view component needs to change.
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

export const OPERATIONAL_METRICS: OperationalMetric[] = [
  {
    key: "active-incidents",
    label: "Active incidents",
    value: 3,
    caption: "1 major · 2 localised",
    tone: "high",
    source: "S3",
  },
  {
    key: "active-responders",
    label: "Active responders",
    value: 47,
    caption: "12 rescue · 9 medical · 26 volunteer",
    tone: "nominal",
    source: "S3",
  },
  {
    key: "active-hazards",
    label: "Active hazards",
    value: 5,
    caption: "2 structural · 2 gas · 1 flood",
    tone: "elevated",
    source: "S3",
  },
  {
    key: "pending-sync",
    label: "Pending synchronisation",
    value: 126,
    caption: "Operations queued on field devices",
    tone: "info",
    source: "S4",
  },
];

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
  { area: "Incidents", detail: "Declaration, sectors, command structure", state: "planned", slice: "S3" },
  { area: "SOS & hazards", detail: "Distress beacons, hazard reporting", state: "planned", slice: "S3" },
  { area: "Peer synchronisation", detail: "CRDT merge, conflict resolution", state: "planned", slice: "S4" },
  { area: "Mesh transport", detail: "BLE, Wi-Fi Direct, LoRa carriage", state: "planned", slice: "S5" },
];
