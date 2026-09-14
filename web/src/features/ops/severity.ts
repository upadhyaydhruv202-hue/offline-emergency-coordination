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
  LIMITED: "elevated",
  OPEN: "nominal",
  FULL: "high",
  CLOSED: "inactive",
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

export function formatRelative(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";
  const minutes = Math.round((Date.now() - parsed.getTime()) / 60_000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return formatTimestamp(value);
}

export function formatCoords(lat: number | null, lng: number | null): string {
  if (lat === null || lng === null) return "—";
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
}
