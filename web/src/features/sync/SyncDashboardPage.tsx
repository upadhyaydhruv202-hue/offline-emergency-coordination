import { Link } from "react-router-dom";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import { fetchSyncConflicts, fetchSyncDemoScenario, fetchSyncStatus } from "../../lib/api/sync";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { useOperationalQuery } from "../ops/useOperationalQuery";
import { SyncArchitecture } from "./SyncArchitecture";

export function SyncDashboardPage() {
  const status = useOperationalQuery(fetchSyncStatus, [], "Could not load sync status");
  const conflicts = useOperationalQuery(fetchSyncConflicts, [], "Could not load conflicts");
  const demo = useOperationalQuery(fetchSyncDemoScenario, [], "Could not load demo scenario");
  const page = status.state.kind === "ready" ? status.state.page : null;
  const conflictRows = conflicts.state.kind === "ready" ? conflicts.state.page : [];
  const scenario = demo.state.kind === "ready" ? demo.state.page : null;

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
    </div>
  );
}
