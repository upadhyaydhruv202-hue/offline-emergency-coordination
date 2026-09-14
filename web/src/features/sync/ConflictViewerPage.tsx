import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import { fetchSyncConflicts, fetchSyncDemoScenario } from "../../lib/api/sync";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { formatTimestamp } from "../ops/severity";
import { useOperationalQuery } from "../ops/useOperationalQuery";

export function ConflictViewerPage() {
  const conflicts = useOperationalQuery(fetchSyncConflicts, [], "Could not load conflicts");
  const demo = useOperationalQuery(fetchSyncDemoScenario, [], "Could not load demo");
  const rows = conflicts.state.kind === "ready" ? conflicts.state.page : [];
  const scenario = demo.state.kind === "ready" ? demo.state.page : null;

  return (
    <div className="mx-auto max-w-4xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Conflict viewer</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Conflicts are recorded even when the CRDT resolves them automatically.
          </p>
        </div>
        <StatusPill tone="info">DETERMINISTIC MERGE</StatusPill>
      </div>

      {conflicts.state.kind === "unreachable" && <BackendUnreachable onRetry={conflicts.reload} />}

      {scenario && (
        <Panel title="CONFLICT DETECTED" subtitle="Road R-12 · development scenario · SIMULATED SYNC">
          <div className="grid gap-4 px-4 py-4 sm:grid-cols-2">
            <article className="rounded-sm border border-navy-700 p-3">
              <p className="label-caps text-ink-500">Device A · {scenario.device_a.device_id}</p>
              <p className="mt-2 text-lg font-semibold text-ink-100">
                {scenario.device_a.type.replaceAll("_", " ")}
              </p>
              <p className="text-sm text-ink-400">{scenario.device_a.severity}</p>
            </article>
            <article className="rounded-sm border border-navy-700 p-3">
              <p className="label-caps text-ink-500">Device B · {scenario.device_b.device_id}</p>
              <p className="mt-2 text-lg font-semibold text-ink-100">
                {scenario.device_b.type.replaceAll("_", " ")}
              </p>
              <p className="text-sm text-ink-400">{scenario.device_b.severity}</p>
            </article>
          </div>
          <div className="border-t border-navy-700 px-4 py-4 text-sm">
            <p className="label-caps text-ink-500">Resolution</p>
            <p className="mt-1 text-ink-100">{scenario.resolution.replaceAll("_", " ")}</p>
            <p className="mt-2 text-nominal">
              Winner {scenario.winner_device}: {scenario.final_state.type.replaceAll("_", " ")} ·{" "}
              {scenario.final_state.severity}
            </p>
            <p className="mt-3 text-xs text-ink-500">DEVICES CONVERGED · not mesh networking</p>
          </div>
        </Panel>
      )}

      <Panel title="Ingested conflicts" subtitle="From POST /sync/push on this peer">
        {conflicts.state.kind === "loading" && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">Loading…</p>
        )}
        {conflicts.state.kind === "ready" && rows.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">
            No operations have been pushed to this peer yet. Seed with{" "}
            <code>python -m app.db.seed --sync-demo</code> or run the mobile simulator.
          </p>
        )}
        {rows.length > 0 && (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="px-4 py-2">Entity</th>
                <th className="px-4 py-2">Resolution</th>
                <th className="px-4 py-2">Detected</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="border-b border-navy-800">
                  <td className="px-4 py-2">
                    {row.entity_type} · {row.entity_id.slice(0, 8)}
                  </td>
                  <td className="px-4 py-2">{row.resolution.replaceAll("_", " ")}</td>
                  <td className="px-4 py-2 text-ink-400">{formatTimestamp(row.detected_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
