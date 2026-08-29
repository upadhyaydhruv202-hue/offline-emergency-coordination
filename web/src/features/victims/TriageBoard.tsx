import { TRIAGE_CATEGORIES, type TriageCategory, type VictimBoard } from "../../lib/api/victims";
import { TRIAGE_BAR, TRIAGE_CAPTION } from "./triageVisuals";

const COUNT_KEYS: Record<TriageCategory, keyof VictimBoard["by_triage"]> = {
  CRITICAL: "critical",
  URGENT: "urgent",
  MODERATE: "moderate",
  STABLE: "stable",
};

/**
 * The counts a commander reads first. Every category is always shown, including
 * the empty ones: a missing CRITICAL column and a CRITICAL count of zero must
 * never look the same.
 */
export function TriageBoard({ board }: { board: VictimBoard }) {
  return (
    <section aria-label="Triage summary" className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
      <article className="panel relative overflow-hidden p-4">
        <span className="absolute inset-y-0 left-0 w-0.5 bg-accent-500" aria-hidden />
        <p className="label-caps">Total victims</p>
        <p className="mt-2 font-mono text-3xl font-semibold tabular-nums text-ink-100">
          {board.total}
        </p>
        <p className="mt-1 text-xs leading-relaxed text-ink-400">
          {board.open_cases} open · {board.evacuated} evacuated
        </p>
      </article>

      {TRIAGE_CATEGORIES.map((category) => (
        <article key={category} className="panel relative overflow-hidden p-4">
          <span className={`absolute inset-y-0 left-0 w-0.5 ${TRIAGE_BAR[category]}`} aria-hidden />
          <p className="label-caps">{category}</p>
          <p className="mt-2 font-mono text-3xl font-semibold tabular-nums text-ink-100">
            {board.by_triage[COUNT_KEYS[category]]}
          </p>
          <p className="mt-1 text-xs leading-relaxed text-ink-400">{TRIAGE_CAPTION[category]}</p>
        </article>
      ))}
    </section>
  );
}
