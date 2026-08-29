import { StatusPill } from "../../components/ui/StatusPill";
import { STATUS_LABELS, type Victim } from "../../lib/api/victims";
import { STATUS_TONE, TRIAGE_BAR, TRIAGE_TONE } from "./triageVisuals";

function formatTimestamp(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";
  return parsed.toLocaleString(undefined, {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function describe(victim: Victim): string {
  const parts = [
    victim.age === null ? null : `${victim.age}`,
    victim.gender === "UNKNOWN" ? null : victim.gender.toLowerCase(),
  ].filter(Boolean);
  return parts.length > 0 ? parts.join(" · ") : "—";
}

/** The roster, ordered by the backend: most urgent first. */
export function VictimTable({ victims }: { victims: Victim[] }) {
  return (
    <table className="w-full text-sm">
      <caption className="sr-only">
        Victims registered on field devices, ordered by triage severity
      </caption>
      <thead>
        <tr className="border-b border-navy-700 text-left">
          <th scope="col" className="label-caps px-4 py-2 font-semibold">
            Triage
          </th>
          <th scope="col" className="label-caps px-4 py-2 font-semibold">
            Tag
          </th>
          <th scope="col" className="label-caps px-4 py-2 font-semibold">
            Name
          </th>
          <th scope="col" className="label-caps hidden px-4 py-2 font-semibold md:table-cell">
            Age / gender
          </th>
          <th scope="col" className="label-caps hidden px-4 py-2 font-semibold lg:table-cell">
            Injury
          </th>
          <th scope="col" className="label-caps px-4 py-2 font-semibold">
            Status
          </th>
          <th scope="col" className="label-caps hidden px-4 py-2 text-right font-semibold sm:table-cell">
            Updated
          </th>
        </tr>
      </thead>
      <tbody>
        {victims.map((victim) => (
          <tr key={victim.id} className="border-b border-navy-800 last:border-0">
            <td className="relative px-4 py-2.5">
              <span
                className={`absolute inset-y-0 left-0 w-0.5 ${TRIAGE_BAR[victim.triage_category]}`}
                aria-hidden
              />
              <StatusPill tone={TRIAGE_TONE[victim.triage_category]}>
                {victim.triage_category}
              </StatusPill>
            </td>
            <td className="px-4 py-2.5 font-mono text-xs text-ink-300">{victim.temporary_id}</td>
            <td className="px-4 py-2.5 font-medium text-ink-200">
              {victim.name ?? <span className="text-ink-500">Unidentified</span>}
            </td>
            <td className="hidden px-4 py-2.5 text-ink-400 md:table-cell">{describe(victim)}</td>
            <td className="hidden px-4 py-2.5 text-ink-400 lg:table-cell">
              {victim.injury_type ?? "—"}
            </td>
            <td className="px-4 py-2.5">
              <StatusPill tone={STATUS_TONE[victim.status]} showDot={false}>
                {STATUS_LABELS[victim.status]}
              </StatusPill>
            </td>
            <td className="hidden px-4 py-2.5 text-right font-mono text-xs text-ink-500 sm:table-cell">
              {formatTimestamp(victim.updated_at)}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
