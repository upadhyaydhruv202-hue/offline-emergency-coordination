import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import type { Facility } from "../../lib/api/command";
import { useCommandStatus } from "../command/commandStatus";
import { formatRelative, formatTimestamp, SEVERITY_TONE } from "../ops/severity";

interface Props {
  kind: Facility["kind"];
  title: string;
  summary: string;
}

export function FacilitiesPage({ kind, title, summary }: Props) {
  const { snapshot } = useCommandStatus();
  const rows = (snapshot?.facilities ?? []).filter((item) => item.kind === kind);

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">{title}</h1>
          <p className="mt-0.5 text-sm text-ink-400">{summary}</p>
        </div>
        <StatusPill tone="info">Slice 5 — COP resources</StatusPill>
      </div>
      <Panel title="Facility roster" subtitle={`${rows.length} records on this peer`}>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-navy-700 text-left">
              <th className="label-caps px-4 py-2">Name</th>
              <th className="label-caps px-4 py-2">Status</th>
              <th className="label-caps px-4 py-2">Capacity</th>
              <th className="label-caps px-4 py-2">Remaining</th>
              <th className="label-caps px-4 py-2">Updated</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id} className="border-b border-navy-800">
                <td className="px-4 py-2">
                  <p className="font-medium text-ink-100">{row.name}</p>
                  <p className="font-mono text-xs text-ink-500">{row.facility_code}</p>
                </td>
                <td className="px-4 py-2">
                  <StatusPill tone={SEVERITY_TONE[row.status] ?? "info"}>{row.status}</StatusPill>
                  {row.emergency_available && kind === "HOSPITAL" ? (
                    <span className="ml-2 text-xs text-nominal">Emergency open</span>
                  ) : null}
                </td>
                <td className="px-4 py-2 text-ink-300">
                  {row.occupancy} / {row.capacity_total}
                </td>
                <td className="px-4 py-2 font-mono text-ink-100">{row.remaining}</td>
                <td className="px-4 py-2 text-ink-400" title={formatTimestamp(row.updated_at)}>
                  {formatRelative(row.updated_at)}
                </td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-ink-500">
                  No {title.toLowerCase()} uploaded to this peer.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </Panel>
    </div>
  );
}

export function HospitalsPage() {
  return (
    <FacilitiesPage
      kind="HOSPITAL"
      title="Hospitals"
      summary="Bed capacity last reported to this coordination peer"
    />
  );
}

export function SheltersPage() {
  return (
    <FacilitiesPage
      kind="SHELTER"
      title="Shelters"
      summary="Occupancy last reported to this coordination peer"
    />
  );
}

export function ResourcesPage() {
  return (
    <FacilitiesPage
      kind="RESOURCE_CACHE"
      title="Resources"
      summary="Staging caches. Figures are reported stock, not a warehouse system."
    />
  );
}
