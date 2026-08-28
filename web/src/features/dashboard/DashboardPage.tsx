import { Panel } from "../../components/ui/Panel";
import { DemoDataNotice } from "../../components/ui/DemoDataNotice";
import { StatusPill } from "../../components/ui/StatusPill";
import { ROLE_LABELS } from "../../lib/api/auth";
import { useAuth } from "../auth/useAuth";
import { MetricTile } from "./MetricTile";
import { CAPABILITY_LEDGER, OPERATIONAL_METRICS } from "./operationalSnapshot";

export function DashboardPage() {
  const { user } = useAuth();

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Operational overview</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Signed in as {user?.full_name} · {user ? ROLE_LABELS[user.role] : ""}
          </p>
        </div>
        <StatusPill tone="info">Slice 1 — foundation</StatusPill>
      </div>

      <DemoDataNotice />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
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
                  <span className={index < 2 ? "text-nominal" : undefined}>{stage}</span>
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
