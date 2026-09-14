import type { StatusTone } from "../../components/ui/StatusPill";

export const SEVERITY_TONE: Record<string, StatusTone> = {
  CRITICAL: "critical",
  HIGH: "high",
  MEDIUM: "elevated",
  LOW: "nominal",
  ACTIVE: "high",
  PAUSED: "elevated",
  RESOLVED: "nominal",
  REPORTED: "elevated",
  VERIFIED: "info",
  CREATED: "critical",
  ACKNOWLEDGED: "elevated",
  PENDING: "inactive",
  ACCEPTED: "info",
  IN_PROGRESS: "elevated",
  COMPLETED: "nominal",
  CANCELLED: "inactive",
};

export function formatTimestamp(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";
  return parsed.toLocaleString(undefined, {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatCoords(lat: number | null, lng: number | null): string {
  if (lat === null || lng === null) return "—";
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
}
