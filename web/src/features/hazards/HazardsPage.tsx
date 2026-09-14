import { Search } from "lucide-react";
import { useState } from "react";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import {
  HAZARD_SEVERITIES,
  HAZARD_STATUSES,
  HAZARD_STATUS_LABELS,
  HAZARD_TYPES,
  fetchHazards,
  type HazardSeverity,
  type HazardStatus,
  type HazardType,
} from "../../lib/api/hazards";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { formatCoords, formatTimestamp, SEVERITY_TONE } from "../ops/severity";
import { useOperationalQuery } from "../ops/useOperationalQuery";

export function HazardsPage() {
  const [search, setSearch] = useState("");
  const [type, setType] = useState<HazardType | null>(null);
  const [severity, setSeverity] = useState<HazardSeverity | null>(null);
  const [status, setStatus] = useState<HazardStatus | null>(null);
  const { state, reload } = useOperationalQuery(
    (token, signal) => fetchHazards(token, { search, type, severity, status }, signal),
    [search, type, severity, status],
    "Could not load hazards",
  );
  const page = state.kind === "ready" ? state.page : null;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Hazards</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Field reports of flood, fire, collapse and other ground hazards
          </p>
        </div>
        <StatusPill tone="info">Slice 3 — field operations</StatusPill>
      </div>

      <CountBoard
        label="Hazard summary"
        tiles={[
          { label: "Total", value: page?.total ?? 0, tone: "info" },
          { label: "CRITICAL", value: page?.items.filter((item) => item.severity === "CRITICAL").length ?? 0, tone: "critical" },
          { label: "HIGH", value: page?.items.filter((item) => item.severity === "HIGH").length ?? 0, tone: "high" },
          { label: "Open", value: page?.items.filter((item) => item.status !== "RESOLVED").length ?? 0, tone: "elevated" },
        ]}
      />

      <Panel title="Hazard roster" subtitle="Most severe first">
        <div className="flex flex-wrap gap-2 border-b border-navy-700 px-4 py-3">
          <label className="relative min-w-56 flex-1">
            <span className="sr-only">Search hazards</span>
            <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-ink-500" />
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search code or description"
              className="w-full rounded-sm border border-navy-600 bg-navy-900 py-1.5 pl-8 pr-3 text-sm text-ink-200 placeholder:text-ink-500"
            />
          </label>
          <select aria-label="Filter by type" value={type ?? ""} onChange={(event) => setType((event.target.value || null) as HazardType | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All types</option>
            {HAZARD_TYPES.map((value) => <option key={value} value={value}>{value.replaceAll("_", " ")}</option>)}
          </select>
          <select aria-label="Filter by severity" value={severity ?? ""} onChange={(event) => setSeverity((event.target.value || null) as HazardSeverity | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All severities</option>
            {HAZARD_SEVERITIES.map((value) => <option key={value} value={value}>{value}</option>)}
          </select>
          <select aria-label="Filter by status" value={status ?? ""} onChange={(event) => setStatus((event.target.value || null) as HazardStatus | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All statuses</option>
            {HAZARD_STATUSES.map((value) => <option key={value} value={value}>{HAZARD_STATUS_LABELS[value]}</option>)}
          </select>
        </div>
        {state.kind === "loading" && <p className="px-4 py-8 text-center text-sm text-ink-500">Loading hazards…</p>}
        {state.kind === "unreachable" && <BackendUnreachable onRetry={reload} />}
        {state.kind === "error" && <p role="alert" className="px-4 py-8 text-center text-sm text-critical">{state.message}</p>}
        {page && page.items.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">
            {page.total === 0 ? "No hazards have been uploaded from the field yet." : "No hazards match this filter."}
          </p>
        )}
        {page && page.items.length > 0 && (
          <table className="w-full text-sm">
            <caption className="sr-only">Hazards reported on field devices</caption>
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="label-caps px-4 py-2">Severity</th>
                <th className="label-caps px-4 py-2">Code</th>
                <th className="label-caps px-4 py-2">Type</th>
                <th className="label-caps hidden px-4 py-2 lg:table-cell">Location</th>
                <th className="label-caps px-4 py-2">Status</th>
                <th className="label-caps hidden px-4 py-2 text-right sm:table-cell">Observed</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((hazard) => (
                <tr key={hazard.id} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2.5"><StatusPill tone={SEVERITY_TONE[hazard.severity]}>{hazard.severity}</StatusPill></td>
                  <td className="px-4 py-2.5 font-mono text-xs text-ink-300">{hazard.hazard_code}</td>
                  <td className="px-4 py-2.5 text-ink-200">{hazard.type.replaceAll("_", " ")}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 lg:table-cell">{formatCoords(hazard.latitude, hazard.longitude)}</td>
                  <td className="px-4 py-2.5"><StatusPill tone={SEVERITY_TONE[hazard.status] ?? "inactive"}>{HAZARD_STATUS_LABELS[hazard.status]}</StatusPill></td>
                  <td className="hidden px-4 py-2.5 text-right font-mono text-xs text-ink-500 sm:table-cell">{formatTimestamp(hazard.observed_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
