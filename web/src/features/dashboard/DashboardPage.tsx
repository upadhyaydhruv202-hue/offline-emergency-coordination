import { Link } from "react-router-dom";
import { Panel } from "../../components/ui/Panel";
import { DemoDataNotice } from "../../components/ui/DemoDataNotice";
import { StatusPill } from "../../components/ui/StatusPill";
import { ROLE_LABELS } from "../../lib/api/auth";
import { useAuth } from "../auth/useAuth";
import { useCommandStatus } from "../command/commandStatus";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { formatRelative, formatTimestamp, SEVERITY_TONE } from "../ops/severity";
import { Tile } from "./MetricTile";
import { CAPABILITY_LEDGER } from "./operationalSnapshot";

export function DashboardPage() {
  const { user } = useAuth();
  const { snapshot, connection, error, reload } = useCommandStatus();
  const kpis = snapshot?.kpis;
  const stale = connection !== "live";

  return (
    <div className="mx-auto max-w-[1600px] space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Operational overview</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Signed in as {user?.full_name} · {user ? ROLE_LABELS[user.role] : ""}
          </p>
        </div>
        <StatusPill tone="info">Slice 5 — command centre</StatusPill>
      </div>

      {connection === "offline" && !snapshot ? (
        <BackendUnreachable onRetry={reload} />
      ) : null}
      {stale && snapshot ? (
        <p role="status" className="rounded-sm border border-elevated/40 bg-elevated/10 px-3 py-2 text-sm text-elevated">
          {error ?? "Data may be stale — connection unavailable"}
        </p>
      ) : null}

      <DemoDataNotice>
        synchronisation is SIMULATED SYNC (peer ingest), not mesh. KPI counts are live from the
        coordination backend. Seed with --command-center for the Ahmedabad COP demo.
      </DemoDataNotice>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Tile label="Active incidents" value={kpis?.active_incidents ?? "—"} caption="Currently consuming field resources" tone="high" />
        <Tile label="Critical victims" value={kpis?.critical_victims ?? "—"} caption="Immediate, life threatening" tone="critical" />
        <Tile label="Active responders" value={kpis?.active_responders ?? "—"} caption="On duty or unreported (not off duty)" tone="nominal" />
        <Tile label="Active SOS alerts" value={kpis?.active_sos ?? "—"} caption="Created or acknowledged" tone="critical" />
        <Tile label="Open hazards" value={kpis?.open_hazards ?? "—"} caption="Reported or verified" tone="elevated" />
        <Tile label="Blocked roads" value={kpis?.blocked_roads ?? "—"} caption="Blocked or partially accessible" tone="high" />
        <Tile label="Hospital capacity" value={kpis?.hospital_beds_remaining ?? "—"} caption="Beds remaining across hospitals" tone="info" />
        <Tile label="Pending tasks" value={kpis?.pending_tasks ?? "—"} caption="Not completed or cancelled" tone="elevated" />
      </div>

      {snapshot && snapshot.alerts.length > 0 && (
        <Panel title="Operational alerts" subtitle="Highest-priority COP warnings only">
          <ul className="divide-y divide-navy-800">
            {snapshot.alerts.map((alert) => (
              <li key={alert.code}>
                <Link
                  to={alert.href}
                  className="flex items-center justify-between gap-3 px-4 py-2.5 text-sm hover:bg-navy-800"
                >
                  <span>
                    <StatusPill tone={SEVERITY_TONE[alert.severity] ?? "info"}>{alert.title}</StatusPill>
                    <span className="ml-2 text-ink-300">{alert.detail}</span>
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </Panel>
      )}

      <div className="grid gap-5 xl:grid-cols-[1.3fr_1fr]">
        <Panel
          title="Active incidents"
          subtitle="Common operational picture"
          actions={
            <Link to="/map" className="text-xs text-accent-400">
              Open live map
            </Link>
          }
        >
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="label-caps px-4 py-2">Incident</th>
                <th className="label-caps px-4 py-2">Zone</th>
                <th className="label-caps px-4 py-2">Status</th>
                <th className="label-caps px-4 py-2">Updated</th>
              </tr>
            </thead>
            <tbody>
              {(snapshot?.incidents ?? []).map((incident) => (
                <tr key={incident.id} className="border-b border-navy-800">
                  <td className="px-4 py-2">
                    <p className="font-medium text-ink-100">{incident.title}</p>
                    <p className="font-mono text-xs text-ink-500">{incident.incident_code}</p>
                  </td>
                  <td className="px-4 py-2 text-ink-300">{incident.assigned_zone ?? "—"}</td>
                  <td className="px-4 py-2">
                    <StatusPill tone={SEVERITY_TONE[incident.status]}>{incident.status}</StatusPill>
                  </td>
                  <td className="px-4 py-2 text-ink-400" title={formatTimestamp(incident.updated_at)}>
                    {formatRelative(incident.updated_at)}
                  </td>
                </tr>
              ))}
              {!snapshot?.incidents.length && (
                <tr>
                  <td colSpan={4} className="px-4 py-6 text-sm text-ink-500">
                    No incidents uploaded to this peer yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </Panel>

        <Panel title="Incident activity" subtitle="From the audit feed on this peer">
          <ol className="max-h-80 space-y-2 overflow-y-auto px-4 py-3 text-sm">
            {(snapshot?.activity ?? []).map((event) => (
              <li key={event.id}>
                <p className="text-ink-200">{event.summary}</p>
                <p className="text-xs text-ink-500">
                  {event.category} · {formatRelative(event.occurred_at)}
                </p>
              </li>
            ))}
            {!snapshot?.activity.length && <li className="text-ink-500">No activity recorded.</li>}
          </ol>
        </Panel>
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        <Panel
          title="Synchronisation"
          subtitle="SIMULATED SYNC"
          actions={
            <Link to="/sync/conflicts" className="text-xs text-accent-400">
              Conflict viewer
            </Link>
          }
        >
          <dl className="grid grid-cols-2 gap-3 px-4 py-3 text-sm">
            <div>
              <dt className="label-caps">Pending</dt>
              <dd className="font-mono text-ink-100">{snapshot?.sync.pending ?? "—"}</dd>
            </div>
            <div>
              <dt className="label-caps">Conflicts</dt>
              <dd className="font-mono text-ink-100">{snapshot?.sync.conflicts ?? "—"}</dd>
            </div>
            <div>
              <dt className="label-caps">Devices seen</dt>
              <dd className="font-mono text-ink-100">{snapshot?.sync.distinct_devices ?? "—"}</dd>
            </div>
            <div>
              <dt className="label-caps">Transport</dt>
              <dd className="text-ink-100">{snapshot?.sync.transport ?? "SIMULATED SYNC"}</dd>
            </div>
          </dl>
        </Panel>

        <Panel title="Capability ledger" subtitle="What this build actually does">
          <table className="w-full text-sm">
            <tbody>
              {CAPABILITY_LEDGER.map((row) => (
                <tr key={row.area} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2 font-medium text-ink-200">{row.area}</td>
                  <td className="px-4 py-2 text-right">
                    <StatusPill tone={row.state === "live" ? "nominal" : "inactive"}>
                      {row.state === "live" ? "Implemented" : row.slice}
                    </StatusPill>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      </div>
    </div>
  );
}
