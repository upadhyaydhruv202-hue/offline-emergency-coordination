import { useCallback } from "react";
import { Panel } from "../../components/ui/Panel";
import { DemoDataNotice } from "../../components/ui/DemoDataNotice";
import { StatusPill } from "../../components/ui/StatusPill";
import { ROLE_LABELS } from "../../lib/api/auth";
import { fetchHazardBoard } from "../../lib/api/hazards";
import { fetchIncidentBoard } from "../../lib/api/incidents";
import { fetchResponders } from "../../lib/api/responders";
import { fetchSosBoard } from "../../lib/api/sos";
import { useAuth } from "../auth/useAuth";
import { useBoard } from "../ops/useOperationalQuery";
import { useVictimBoard } from "../victims/useVictims";
import { MetricTile, Tile } from "./MetricTile";
import { CAPABILITY_LEDGER, OPERATIONAL_METRICS } from "./operationalSnapshot";

export function DashboardPage() {
  const { user } = useAuth();
  const board = useVictimBoard();
  const incidents = useBoard(useCallback(fetchIncidentBoard, []));
  const hazards = useBoard(useCallback(fetchHazardBoard, []));
  const sos = useBoard(useCallback(fetchSosBoard, []));
  const responders = useBoard(
    useCallback((token: string, signal: AbortSignal) => fetchResponders(token, {}, signal), []),
  );

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Operational overview</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Signed in as {user?.full_name} · {user ? ROLE_LABELS[user.role] : ""}
          </p>
        </div>
        <StatusPill tone="info">Slice 3 — field operations</StatusPill>
      </div>

      <DemoDataNotice>
        the pending-synchronisation figure is hard-coded. Victim, incident, responder, hazard and
        SOS counts are live from the coordination backend. Field devices do not upload yet, so
        those pages may honestly be empty.
      </DemoDataNotice>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <Tile
          label="Registered victims"
          value={board?.total ?? "—"}
          caption={board ? `${board.open_cases} open · ${board.evacuated} evacuated` : "No uplink"}
          tone="info"
        />
        <Tile
          label="Critical victims"
          value={board?.by_triage.critical ?? "—"}
          caption="Immediate, life threatening"
          tone="critical"
        />
        <Tile
          label="Active incidents"
          value={incidents?.by_status.active ?? "—"}
          caption={incidents ? `${incidents.total} uploaded` : "No uplink"}
          tone="high"
        />
        <Tile
          label="Active responders"
          value={responders?.total ?? "—"}
          caption="Accounts that can hold a field device"
          tone="nominal"
        />
        <Tile
          label="Active hazards"
          value={
            hazards
              ? hazards.by_status.reported + hazards.by_status.verified
              : "—"
          }
          caption={sos ? `${sos.by_status.created + sos.by_status.acknowledged} open SOS` : "No uplink"}
          tone="elevated"
        />
        {OPERATIONAL_METRICS.map((metric) => (
          <MetricTile key={metric.key} metric={metric} />
        ))}
      </div>

      <div className="grid gap-5 lg:grid-cols-[1.4fr_1fr]">
        <Panel
          title="Capability ledger"
          subtitle="What this build actually does, and what it does not"
        >
          <table className="w-full text-sm">
            <caption className="sr-only">
              Implemented and planned platform capabilities by development slice
            </caption>
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th scope="col" className="label-caps px-4 py-2 font-semibold">
                  Capability
                </th>
                <th scope="col" className="label-caps hidden px-4 py-2 font-semibold sm:table-cell">
                  Detail
                </th>
                <th scope="col" className="label-caps px-4 py-2 text-right font-semibold">
                  State
                </th>
              </tr>
            </thead>
            <tbody>
              {CAPABILITY_LEDGER.map((row) => (
                <tr key={row.area} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2.5 font-medium text-ink-200">{row.area}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 sm:table-cell">{row.detail}</td>
                  <td className="px-4 py-2.5 text-right">
                    <StatusPill tone={row.state === "live" ? "nominal" : "inactive"}>
                      {row.state === "live" ? "Implemented" : row.slice}
                    </StatusPill>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>

        <Panel title="Architecture invariant" subtitle="The rule every slice must preserve">
          <div className="space-y-4 p-4">
            <blockquote className="border-l-2 border-accent-500 pl-3 text-sm leading-relaxed text-ink-200">
              Field devices must remain operational even when disconnected from the internet.
            </blockquote>

            <ol className="space-y-1.5 font-mono text-xs text-ink-400">
              {[
                "field device",
                "local database",
                "local operational state",
                "peer synchronisation",
                "conflict resolution",
                "shared operational state",
                "digital twin",
                "decision support",
                "coordinated response",
              ].map((stage, index) => (
                <li key={stage} className="flex gap-2">
                  <span className="text-ink-500 tabular-nums">
                    {String(index + 1).padStart(2, "0")}
                  </span>
                  <span className={index < 3 ? "text-nominal" : undefined}>{stage}</span>
                </li>
              ))}
            </ol>

            <p className="border-t border-navy-700 pt-3 text-xs leading-relaxed text-ink-500">
              Stages shown in green are implemented. This command centre is a synchronisation peer,
              not a dependency of the field device.
            </p>
          </div>
        </Panel>
      </div>
    </div>
  );
}
