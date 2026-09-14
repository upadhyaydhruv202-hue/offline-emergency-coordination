import { describe, expect, it } from "vitest";
import { DEFAULT_FILTERS, filterMarkers, type MapFilters } from "./filterMarkers";
import type { MapMarker } from "../../lib/api/command";

const markers: MapMarker[] = [
  {
    id: "v1",
    layer: "victims",
    label: "V-1",
    latitude: 23,
    longitude: 72,
    status: "REGISTERED",
    severity: "CRITICAL",
    kind: null,
    subtitle: null,
  },
  {
    id: "v2",
    layer: "victims",
    label: "V-2",
    latitude: 23.1,
    longitude: 72.1,
    status: "REGISTERED",
    severity: "STABLE",
    kind: null,
    subtitle: null,
  },
  {
    id: "h1",
    layer: "roadblocks",
    label: "R-12",
    latitude: 23.2,
    longitude: 72.2,
    status: "VERIFIED",
    severity: "HIGH",
    kind: "ROAD_BLOCKED",
    subtitle: null,
  },
];

describe("map filters", () => {
  it("keeps all markers with default filters", () => {
    expect(filterMarkers(markers, DEFAULT_FILTERS)).toHaveLength(3);
  });

  it("filters victims by triage", () => {
    const filters: MapFilters = { ...DEFAULT_FILTERS, triage: "CRITICAL" };
    expect(filterMarkers(markers, filters).map((item) => item.id)).toEqual(["v1", "h1"]);
  });

  it("hides a layer when unchecked", () => {
    const layers = new Set(DEFAULT_FILTERS.layers);
    layers.delete("roadblocks");
    expect(filterMarkers(markers, { ...DEFAULT_FILTERS, layers })).toHaveLength(2);
  });
});
