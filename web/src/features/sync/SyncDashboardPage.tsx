import { Link } from "react-router-dom";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import { fetchSyncConflicts, fetchSyncDemoScenario, fetchSyncOperations, fetchSyncStatus } from "../../lib/api/sync";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { useOperationalQuery } from "../ops/useOperationalQuery";
import { SyncArchitecture } from "./SyncArchitecture";

export function SyncDashboardPage() {
  const status = useOperationalQuery(fetchSyncStatus, [], "Could not load sync status");
  const conflicts = useOperationalQuery(fetchSyncConflicts, [], "Could not load conflicts");
  const demo = useOperationalQuery(fetchSyncDemoScenario, [], "Could not load demo scenario");
  const operations = useOperationalQuery(fetchSyncOperations, [], "Could not load operations");
  const page = status.state.kind === "ready" ? status.state.page : null;
  const conflictRows = conflicts.state.kind === "ready" ? conflicts.state.page : [];
  const scenario = demo.state.kind === "ready" ? demo.state.page : null;
  const ops = operations.state.kind === "ready" ? operations.state.page : null;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Synchronisation</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Peer ingest of field operations. Deterministic CRDT merge. Not mesh networking.
          </p>
        </div>
        <StatusPill tone="info">Slice 4 — simulated sync</StatusPill>
      </div>

      {status.state.kind === "unreachable" ? (
        <BackendUnreachable onRetry={status.reload} />
      ) : (
        <CountBoard
          label="Sync queue"
          tiles={[
            { label: "Pending", value: page?.pending ?? 0, tone: "elevated" },
            { label: "In flight", value: page?.in_flight ?? 0, tone: "info" },
            { label: "Acknowledged", value: page?.acknowledged ?? 0, tone: "nominal" },
            { label: "Conflicts", value: page?.conflicts ?? 0, tone: "high" },
            { label: "Failed", value: page?.failed ?? 0, tone: "critical" },
          ]}
        />
      )}

      <Panel title="Convergence" subtitle={page?.note ?? "Development peer, not a central source of truth"}>
        <div className="space-y-2 px-4 py-3 text-sm text-ink-300">
          <p>Last ingest: {page?.last_push_at ?? "Never"}</p>
          <p>
            {conflictRows.length === 0
              ? "No conflicts ingested on this peer yet."
              : `${conflictRows.length} conflict(s) recorded after deterministic resolution.`}
          </p>
          <Link to="/sync/conflicts" className="text-accent-400 underline">
            Open conflict viewer
          </Link>
        </div>
      </Panel>

      <Panel title="Architecture" subtitle="Same SyncService + CRDT engine the radios will call later">
        <SyncArchitecture />
      </Panel>

      {scenario && (
        <Panel title="Road R-12 development scenario" subtitle="DEVELOPMENT / DEMO TOOL — not live field traffic">
          <dl className="grid gap-3 px-4 py-3 text-sm sm:grid-cols-2">
            <div>
              <dt className="label-caps text-ink-500">Incident</dt>
              <dd className="text-ink-100">{scenario.incident} · zone {scenario.zone}</dd>
            </div>
            <div>
              <dt className="label-caps text-ink-500">Entity</dt>
              <dd className="text-ink-100">{scenario.entity}</dd>
            </div>
            <div>
              <dt className="label-caps text-ink-500">{scenario.device_a.actor}</dt>
              <dd>
                {scenario.device_a.type} · {scenario.device_a.severity}
              </dd>
            </div>
            <div>
              <dt className="label-caps text-ink-500">{scenario.device_b.actor}</dt>
              <dd>
                {scenario.device_b.type} · {scenario.device_b.severity}
              </dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="label-caps text-ink-500">Deterministic result</dt>
              <dd className="text-nominal">
                Winner {scenario.winner_device}: {scenario.final_state.type} · {scenario.final_state.severity}
              </dd>
            </div>
          </dl>
          <p className="border-t border-navy-700 px-4 py-3 text-xs text-ink-500">{scenario.note}</p>
        </Panel>
      )}

      <Panel title="Sync operations" subtitle="SIMULATED SYNC · ingested peer journal">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-navy-700 text-left">
              <th className="label-caps px-4 py-2">Operation</th>
              <th className="label-caps px-4 py-2">Device</th>
              <th className="label-caps px-4 py-2">Entity</th>
              <th className="label-caps px-4 py-2">Type</th>
              <th className="label-caps px-4 py-2">Ts</th>
              <th className="label-caps px-4 py-2">Status</th>
            </tr>
          </thead>
          <tbody>
            {(ops?.items ?? []).map((row) => (
              <tr key={row.operation_id} className="border-b border-navy-800">
                <td className="px-4 py-2 font-mono text-xs text-ink-300">{row.operation_id.slice(0, 8)}</td>
                <td className="px-4 py-2">{row.device_id}</td>
                <td className="px-4 py-2">
                  {row.entity_type} · {row.entity_id.slice(0, 8)}
                </td>
                <td className="px-4 py-2">{row.operation_type}</td>
                <td className="px-4 py-2 font-mono">{row.logical_timestamp}</td>
                <td className="px-4 py-2">{row.queue_status}</td>
              </tr>
            ))}
            {!ops?.items.length && (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-ink-500">
                  No operations ingested.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </Panel>
    </div>
  );
}
