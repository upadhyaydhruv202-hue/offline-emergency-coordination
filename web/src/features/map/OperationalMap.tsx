import { useEffect, useRef, useState } from "react";
import type { Map as LeafletMap } from "leaflet";
import type { MapMarker } from "../../lib/api/command";
import { fitBounds } from "./filterMarkers";

interface Props {
  markers: MapMarker[];
  selected: MapMarker | null;
  onSelect: (marker: MapMarker) => void;
}

const COLOR: Record<string, string> = {
  CRITICAL: "#e5484d",
  URGENT: "#f76808",
  MODERATE: "#ffb224",
  STABLE: "#30a46c",
  HIGH: "#f76808",
  MEDIUM: "#ffb224",
  LOW: "#30a46c",
  ROAD_BLOCKED: "#e5484d",
  PARTIALLY_ACCESSIBLE: "#f76808",
};

function colorFor(marker: MapMarker): string {
  return COLOR[marker.severity ?? ""] || COLOR[marker.kind ?? ""] || "#58a6ff";
}

export function OperationalMap({ markers, selected, onSelect }: Props) {
  const host = useRef<HTMLDivElement>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const [mapReady, setMapReady] = useState(false);

  useEffect(() => {
    if (import.meta.env.MODE === "test") return;
    const node = host.current;
    if (!node) return;
    let cancelled = false;
    let map: LeafletMap | undefined;
    let observer: ResizeObserver | undefined;

    void (async () => {
      const L = await import("leaflet");
      if (cancelled || mapRef.current) return;
      map = L.map(node, { zoomControl: true }).setView([23.0225, 72.5714], 12);
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors",
        maxZoom: 19,
      }).addTo(map);
      mapRef.current = map;
      observer = new ResizeObserver(() => {
        map?.invalidateSize();
      });
      observer.observe(node);
      map.whenReady(() => {
        map?.invalidateSize();
      });
      setMapReady(true);
    })();

    return () => {
      cancelled = true;
      observer?.disconnect();
      map?.remove();
      mapRef.current = null;
      setMapReady(false);
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !mapReady || import.meta.env.MODE === "test") return;
    let cancelled = false;
    void (async () => {
      const L = await import("leaflet");
      if (cancelled) return;
      map.eachLayer((layer) => {
        if (layer instanceof L.CircleMarker || layer instanceof L.Marker) map.removeLayer(layer);
      });
      for (const marker of markers) {
        const circle = L.circleMarker([marker.latitude, marker.longitude], {
          radius: marker.layer === "incidents" ? 10 : 7,
          color: colorFor(marker),
          fillOpacity: 0.85,
          weight: 2,
        }).addTo(map);
        circle.bindPopup(
          `<strong>${marker.label}</strong><br/>${marker.layer}${marker.subtitle ? `<br/>${marker.subtitle}` : ""}`,
        );
        circle.on("click", () => onSelect(marker));
      }
      const bounds = fitBounds(markers);
      if (bounds) {
        map.invalidateSize();
        map.fitBounds(bounds, { padding: [28, 28], maxZoom: 15 });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [markers, onSelect, mapReady]);

  useEffect(() => {
    if (!selected || !mapRef.current) return;
    mapRef.current.setView([selected.latitude, selected.longitude], 15);
  }, [selected]);

  return (
    <div className="panel overflow-hidden">
      <div
        ref={host}
        className="h-[640px] w-full bg-navy-900"
        data-testid="operational-map"
      />
      {import.meta.env.MODE === "test" && (
        <p className="sr-only">{markers.length} map markers</p>
      )}
    </div>
  );
}
