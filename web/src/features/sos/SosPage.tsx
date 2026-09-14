import { useState } from "react";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import {
  SOS_PRIORITIES,
  SOS_STATUSES,
  SOS_STATUS_LABELS,
  fetchSosEvents,
  type SosPriority,
  type SosStatus,
} from "../../lib/api/sos";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { formatCoords, formatTimestamp, SEVERITY_TONE } from "../ops/severity";
import { useOperationalQuery } from "../ops/useOperationalQuery";

export function SosPage() {
  const [priority, setPriority] = useState<SosPriority | null>(null);
  const [status, setStatus] = useState<SosStatus | null>(null);
  const { state, reload } = useOperationalQuery(
    (token, signal) => fetchSosEvents(token, { priority, status }, signal),
    [priority, status],
    "Could not load SOS events",
  );
  const page = state.kind === "ready" ? state.page : null;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">SOS</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Distress calls raised on field devices. Local until Slice 4 carries them here.
          </p>
        </div>
        <StatusPill tone="info">Slice 3 — field operations</StatusPill>
      </div>

      <CountBoard
        label="SOS summary"
        tiles={[
          { label: "Total", value: page?.total ?? 0, tone: "info" },
          { label: "CRITICAL", value: page?.items.filter((item) => item.priority === "CRITICAL").length ?? 0, tone: "critical" },
          { label: "Open", value: page?.items.filter((item) => item.status !== "RESOLVED").length ?? 0, tone: "high" },
          { label: "Resolved", value: page?.items.filter((item) => item.status === "RESOLVED").length ?? 0, tone: "nominal" },
        ]}
      />

      <Panel title="SOS queue" subtitle="Most urgent first">
        <div className="flex flex-wrap gap-2 border-b border-navy-700 px-4 py-3">
          <select aria-label="Filter by priority" value={priority ?? ""} onChange={(event) => setPriority((event.target.value || null) as SosPriority | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All priorities</option>
            {SOS_PRIORITIES.map((value) => <option key={value} value={value}>{value}</option>)}
          </select>
          <select aria-label="Filter by status" value={status ?? ""} onChange={(event) => setStatus((event.target.value || null) as SosStatus | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All statuses</option>
            {SOS_STATUSES.map((value) => <option key={value} value={value}>{SOS_STATUS_LABELS[value]}</option>)}
          </select>
        </div>
        {state.kind === "loading" && <p className="px-4 py-8 text-center text-sm text-ink-500">Loading SOS queue…</p>}
        {state.kind === "unreachable" && <BackendUnreachable onRetry={reload} />}
        {state.kind === "error" && <p role="alert" className="px-4 py-8 text-center text-sm text-critical">{state.message}</p>}
        {page && page.items.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">
            {page.total === 0 ? "No SOS events have been uploaded from the field yet." : "No SOS events match this filter."}
          </p>
        )}
        {page && page.items.length > 0 && (
          <table className="w-full text-sm">
            <caption className="sr-only">SOS events raised on field devices</caption>
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="label-caps px-4 py-2">Priority</th>
                <th className="label-caps px-4 py-2">Code</th>
                <th className="label-caps hidden px-4 py-2 md:table-cell">Message</th>
                <th className="label-caps hidden px-4 py-2 lg:table-cell">Location</th>
                <th className="label-caps px-4 py-2">Status</th>
                <th className="label-caps hidden px-4 py-2 text-right sm:table-cell">Raised</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((event) => (
                <tr key={event.id} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2.5"><StatusPill tone={SEVERITY_TONE[event.priority]}>{event.priority}</StatusPill></td>
                  <td className="px-4 py-2.5 font-mono text-xs text-ink-300">{event.sos_code}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 md:table-cell">{event.message ?? "—"}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 lg:table-cell">{formatCoords(event.latitude, event.longitude)}</td>
                  <td className="px-4 py-2.5"><StatusPill tone={SEVERITY_TONE[event.status] ?? "inactive"}>{SOS_STATUS_LABELS[event.status]}</StatusPill></td>
                  <td className="hidden px-4 py-2.5 text-right font-mono text-xs text-ink-500 sm:table-cell">{formatTimestamp(event.raised_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
