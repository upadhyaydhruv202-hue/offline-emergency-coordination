import type { StatusTone } from "../../components/ui/StatusPill";
import type { TriageCategory, VictimStatus } from "../../lib/api/victims";

/**
 * Triage colour is the only thing on this page that has to read correctly at a
 * glance, so it maps onto the shell's existing severity palette rather than
 * introducing a second set of colours.
 */
export const TRIAGE_TONE: Record<TriageCategory, StatusTone> = {
  CRITICAL: "critical",
  URGENT: "high",
  MODERATE: "elevated",
  STABLE: "nominal",
};

export const TRIAGE_BAR: Record<TriageCategory, string> = {
  CRITICAL: "bg-critical",
  URGENT: "bg-high",
  MODERATE: "bg-elevated",
  STABLE: "bg-nominal",
};

export const TRIAGE_CAPTION: Record<TriageCategory, string> = {
  CRITICAL: "Immediate, life threatening",
  URGENT: "Serious, short delay tolerated",
  MODERATE: "Walking wounded",
  STABLE: "No intervention required",
};

export const STATUS_TONE: Record<VictimStatus, StatusTone> = {
  REGISTERED: "info",
  UNDER_TREATMENT: "elevated",
  AWAITING_EVACUATION: "high",
  EVACUATED: "nominal",
  DECEASED: "inactive",
};
