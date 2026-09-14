import { Search } from "lucide-react";
import { useState } from "react";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import {
  DISASTER_TYPES,
  INCIDENT_STATUSES,
  INCIDENT_STATUS_LABELS,
  fetchIncidents,
  type DisasterType,
  type IncidentBoard,
  type IncidentStatus,
} from "../../lib/api/incidents";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { formatTimestamp, SEVERITY_TONE } from "../ops/severity";
import { useOperationalQuery } from "../ops/useOperationalQuery";

const EMPTY_BOARD: IncidentBoard = {
  total: 0,
  by_status: { active: 0, paused: 0, resolved: 0 },
};

export function IncidentsPage() {
  const [search, setSearch] = useState("");
  const [disasterType, setDisasterType] = useState<DisasterType | null>(null);
  const [status, setStatus] = useState<IncidentStatus | null>(null);
  const { state, reload } = useOperationalQuery(
    (token, signal) =>
      fetchIncidents(token, { search, disaster_type: disasterType, status }, signal),
    [search, disasterType, status],
    "Could not load incidents",
  );
  const page = state.kind === "ready" ? state.page : null;
  const board = EMPTY_BOARD;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Incidents</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Responses declared on field devices and uploaded when a link is available
          </p>
        </div>
        <StatusPill tone="info">Slice 3 — field operations</StatusPill>
      </div>

      <CountBoard
        label="Incident summary"
        tiles={[
          { label: "Total", value: page?.total ?? board.total, tone: "info", caption: "Uploaded" },
          { label: "ACTIVE", value: page?.items.filter((item) => item.status === "ACTIVE").length ?? 0, tone: "high" },
          { label: "PAUSED", value: page?.items.filter((item) => item.status === "PAUSED").length ?? 0, tone: "elevated" },
          { label: "RESOLVED", value: page?.items.filter((item) => item.status === "RESOLVED").length ?? 0, tone: "nominal" },
        ]}
      />

      <Panel title="Incident roster" subtitle="Most recent first">
        <div className="flex flex-wrap gap-2 border-b border-navy-700 px-4 py-3">
          <label className="relative min-w-56 flex-1">
            <span className="sr-only">Search incidents</span>
            <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-ink-500" />
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search title, code or zone"
              className="w-full rounded-sm border border-navy-600 bg-navy-900 py-1.5 pl-8 pr-3 text-sm text-ink-200 placeholder:text-ink-500"
            />
          </label>
          <select
            aria-label="Filter by disaster type"
            value={disasterType ?? ""}
            onChange={(event) =>
              setDisasterType((event.target.value || null) as DisasterType | null)
            }
            className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200"
          >
            <option value="">All types</option>
            {DISASTER_TYPES.map((type) => (
              <option key={type} value={type}>
                {type.replaceAll("_", " ")}
              </option>
            ))}
          </select>
          <select
            aria-label="Filter by status"
            value={status ?? ""}
            onChange={(event) => setStatus((event.target.value || null) as IncidentStatus | null)}
            className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200"
          >
            <option value="">All statuses</option>
            {INCIDENT_STATUSES.map((value) => (
              <option key={value} value={value}>
                {INCIDENT_STATUS_LABELS[value]}
              </option>
            ))}
          </select>
        </div>

        {state.kind === "loading" && <p className="px-4 py-8 text-center text-sm text-ink-500">Loading incidents…</p>}
        {state.kind === "unreachable" && <BackendUnreachable onRetry={reload} />}
        {state.kind === "error" && (
          <p role="alert" className="px-4 py-8 text-center text-sm text-critical">{state.message}</p>
        )}
        {page && page.items.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">
            {page.total === 0 ? "No incidents have been uploaded from the field yet." : "No incidents match this filter."}
          </p>
        )}
        {page && page.items.length > 0 && (
          <table className="w-full text-sm">
            <caption className="sr-only">Incidents uploaded from field devices</caption>
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="label-caps px-4 py-2">Code</th>
                <th className="label-caps px-4 py-2">Title</th>
                <th className="label-caps hidden px-4 py-2 md:table-cell">Type</th>
                <th className="label-caps hidden px-4 py-2 lg:table-cell">Zone</th>
                <th className="label-caps px-4 py-2">Status</th>
                <th className="label-caps hidden px-4 py-2 text-right sm:table-cell">Updated</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((incident) => (
                <tr key={incident.id} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2.5 font-mono text-xs text-ink-300">{incident.incident_code}</td>
                  <td className="px-4 py-2.5 font-medium text-ink-200">{incident.title}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 md:table-cell">
                    {incident.disaster_type.replaceAll("_", " ")}
                  </td>
                  <td className="hidden px-4 py-2.5 text-ink-400 lg:table-cell">
                    {incident.assigned_zone ?? "—"}
                  </td>
                  <td className="px-4 py-2.5">
                    <StatusPill tone={SEVERITY_TONE[incident.status] ?? "inactive"}>
                      {INCIDENT_STATUS_LABELS[incident.status]}
                    </StatusPill>
                  </td>
                  <td className="hidden px-4 py-2.5 text-right font-mono text-xs text-ink-500 sm:table-cell">
                    {formatTimestamp(incident.updated_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
