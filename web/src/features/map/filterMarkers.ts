import type { MapMarker } from "../../lib/api/command";

export const MAP_LAYERS = [
  "incidents",
  "victims",
  "responders",
  "hazards",
  "roadblocks",
  "hospitals",
  "shelters",
  "resources",
  "sos",
] as const;

export type MapLayer = (typeof MAP_LAYERS)[number];

export interface MapFilters {
  incidentStatus: "ALL" | "ACTIVE" | "RESOLVED";
  triage: "ALL" | "CRITICAL" | "URGENT" | "MODERATE" | "STABLE";
  hazardKind: "ALL" | string;
  responderStatus: "ALL" | string;
  layers: ReadonlySet<string>;
}

export const DEFAULT_FILTERS: MapFilters = {
  incidentStatus: "ALL",
  triage: "ALL",
  hazardKind: "ALL",
  responderStatus: "ALL",
  layers: new Set(MAP_LAYERS),
};

export function filterMarkers(markers: MapMarker[], filters: MapFilters): MapMarker[] {
  return markers.filter((marker) => {
    if (!filters.layers.has(marker.layer)) return false;
    if (marker.layer === "incidents") {
      if (filters.incidentStatus === "ACTIVE" && marker.status !== "ACTIVE") return false;
      if (filters.incidentStatus === "RESOLVED" && marker.status !== "RESOLVED") return false;
    }
    if (marker.layer === "victims" && filters.triage !== "ALL" && marker.severity !== filters.triage) {
      return false;
    }
    if (
      (marker.layer === "hazards" || marker.layer === "roadblocks") &&
      filters.hazardKind !== "ALL" &&
      marker.kind !== filters.hazardKind
    ) {
      return false;
    }
    if (
      marker.layer === "responders" &&
      filters.responderStatus !== "ALL" &&
      marker.status !== filters.responderStatus
    ) {
      return false;
    }
    return true;
  });
}

export function fitBounds(markers: MapMarker[]): [[number, number], [number, number]] | null {
  if (markers.length === 0) return null;
  const lats = markers.map((item) => item.latitude);
  const lngs = markers.map((item) => item.longitude);
  return [
    [Math.min(...lats), Math.min(...lngs)],
    [Math.max(...lats), Math.max(...lngs)],
  ];
}
