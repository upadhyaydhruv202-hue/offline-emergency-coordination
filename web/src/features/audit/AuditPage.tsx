import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import { useCommandStatus } from "../command/commandStatus";
import { formatRelative, formatTimestamp, SEVERITY_TONE } from "../ops/severity";

export function AuditPage() {
  const { snapshot } = useCommandStatus();
  const rows = snapshot?.activity ?? [];

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Audit / Events</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Chronological COP feed from this peer. Not a cryptographic evidence log.
          </p>
        </div>
        <StatusPill tone="info">Slice 5</StatusPill>
      </div>
      <Panel title="Activity" subtitle={`${rows.length} events`}>
        <ol className="divide-y divide-navy-800">
          {rows.map((event) => (
            <li key={event.id} className="px-4 py-3 text-sm">
              <div className="flex items-center gap-2">
                <StatusPill tone={SEVERITY_TONE[event.severity] ?? "info"}>{event.category}</StatusPill>
                <span className="text-ink-200">{event.summary}</span>
              </div>
              <p className="mt-1 text-xs text-ink-500" title={formatTimestamp(event.occurred_at)}>
                {formatRelative(event.occurred_at)}
              </p>
            </li>
          ))}
          {rows.length === 0 && <li className="px-4 py-6 text-ink-500">No events on this peer.</li>}
        </ol>
      </Panel>
    </div>
  );
}
