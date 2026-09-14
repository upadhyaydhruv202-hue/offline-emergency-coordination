import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import type { MapMarker } from "../../lib/api/command";
import { useCommandStatus } from "../command/commandStatus";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { DEFAULT_FILTERS, MAP_LAYERS, filterMarkers, type MapFilters } from "./filterMarkers";
import { OperationalMap } from "./OperationalMap";

const HAZARD_KINDS = [
  "FLOOD",
  "FIRE",
  "SMOKE",
  "ROAD_BLOCKED",
  "PARTIALLY_ACCESSIBLE",
  "BUILDING_DAMAGE",
  "BRIDGE_RISK",
  "OTHER",
];

const RESPONDER_STATUSES = ["AVAILABLE", "EN_ROUTE", "ON_MISSION", "NEEDS_ASSISTANCE", "OFF_DUTY"];

export function MapPage() {
  const { snapshot, connection, reload } = useCommandStatus();
  const [filters, setFilters] = useState<MapFilters>(DEFAULT_FILTERS);
  const [selected, setSelected] = useState<MapMarker | null>(null);
  const visible = useMemo(
    () => filterMarkers(snapshot?.markers ?? [], filters),
    [snapshot, filters],
  );

  function toggleLayer(layer: string) {
    const next = new Set(filters.layers);
    if (next.has(layer)) next.delete(layer);
    else next.add(layer);
    setFilters({ ...filters, layers: next });
  }

  return (
    <div className="mx-auto max-w-[1600px] space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Operational map</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Zone 04 common picture from ingested coordinates. Not a digital twin.
          </p>
        </div>
        <StatusPill tone="info">Slice 5 — Leaflet COP</StatusPill>
      </div>

      {connection === "offline" && !snapshot ? <BackendUnreachable onRetry={reload} /> : null}

      <div className="flex flex-wrap gap-2">
        <select
          aria-label="Filter incidents"
          className="rounded-sm border border-navy-600 bg-navy-900 px-2 py-1.5 text-sm"
          value={filters.incidentStatus}
          onChange={(event) =>
            setFilters({ ...filters, incidentStatus: event.target.value as MapFilters["incidentStatus"] })
          }
        >
          <option value="ALL">Incidents: all</option>
          <option value="ACTIVE">Incidents: active</option>
          <option value="RESOLVED">Incidents: resolved</option>
        </select>
        <select
          aria-label="Filter victim triage"
          className="rounded-sm border border-navy-600 bg-navy-900 px-2 py-1.5 text-sm"
          value={filters.triage}
          onChange={(event) => setFilters({ ...filters, triage: event.target.value as MapFilters["triage"] })}
        >
          <option value="ALL">Triage: all</option>
          <option value="CRITICAL">Critical</option>
          <option value="URGENT">Urgent</option>
          <option value="MODERATE">Moderate</option>
          <option value="STABLE">Stable</option>
        </select>
        <select
          aria-label="Filter hazards"
          className="rounded-sm border border-navy-600 bg-navy-900 px-2 py-1.5 text-sm"
          value={filters.hazardKind}
          onChange={(event) => setFilters({ ...filters, hazardKind: event.target.value })}
        >
          <option value="ALL">Hazards: all</option>
          {HAZARD_KINDS.map((kind) => (
            <option key={kind} value={kind}>
              {kind.replaceAll("_", " ")}
            </option>
          ))}
        </select>
        <select
          aria-label="Filter responder status"
          className="rounded-sm border border-navy-600 bg-navy-900 px-2 py-1.5 text-sm"
          value={filters.responderStatus}
          onChange={(event) => setFilters({ ...filters, responderStatus: event.target.value })}
        >
          <option value="ALL">Responders: all</option>
          {RESPONDER_STATUSES.map((status) => (
            <option key={status} value={status}>
              {status.replaceAll("_", " ")}
            </option>
          ))}
        </select>
        <button
          type="button"
          className="rounded-sm border border-navy-600 px-3 py-1.5 text-sm text-ink-200"
          onClick={() => setFilters(DEFAULT_FILTERS)}
        >
          Reset layers
        </button>
        <button type="button" className="rounded-sm border border-navy-600 px-3 py-1.5 text-sm" onClick={reload}>
          Refresh
        </button>
      </div>

      <div className="flex flex-wrap gap-1">
        {MAP_LAYERS.map((layer) => (
          <label key={layer} className="flex items-center gap-1 rounded-sm border border-navy-700 px-2 py-1 text-xs">
            <input
              type="checkbox"
              checked={filters.layers.has(layer)}
              onChange={() => toggleLayer(layer)}
            />
            {layer}
          </label>
        ))}
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_280px]">
        <OperationalMap markers={visible} selected={selected} onSelect={setSelected} />
        <div className="space-y-4">
          <Panel title="Legend" subtitle="Shape plus colour">
            <ul className="space-y-1 px-4 py-3 text-xs text-ink-300">
              <li>● Victims — Critical / Urgent / Moderate / Stable</li>
              <li>▲ Responders — status in the popup</li>
              <li>■ Hazards and roadblocks</li>
              <li>■ Hospitals / shelters / caches</li>
              <li>○ Incidents and SOS</li>
            </ul>
          </Panel>
          <Panel title="Visible entities" subtitle={`${visible.length} markers`}>
            <ul className="max-h-72 overflow-y-auto divide-y divide-navy-800">
              {visible.map((marker) => (
                <li key={`${marker.layer}-${marker.id}`}>
                  <button
                    type="button"
                    className="w-full px-4 py-2 text-left text-sm hover:bg-navy-800"
                    onClick={() => setSelected(marker)}
                  >
                    <span className="font-medium text-ink-100">{marker.label}</span>
                    <span className="mt-0.5 block text-xs text-ink-500">
                      {marker.layer}
                      {marker.kind ? ` · ${marker.kind}` : ""}
                      {marker.severity ? ` · ${marker.severity}` : ""}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </Panel>
          {selected?.layer === "roadblocks" && (
            <Link to="/sync/conflicts" className="block px-1 text-xs text-accent-400">
              Road R-12 conflict viewer
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
