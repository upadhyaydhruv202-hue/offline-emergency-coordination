import { CloudOff, Search } from "lucide-react";
import { useState } from "react";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import {
  STATUS_LABELS,
  TRIAGE_CATEGORIES,
  VICTIM_STATUSES,
  type TriageCategory,
  type VictimStatus,
} from "../../lib/api/victims";
import { TriageBoard } from "./TriageBoard";
import { useVictims } from "./useVictims";
import { VictimTable } from "./VictimTable";

const EMPTY_BOARD = {
  total: 0,
  open_cases: 0,
  evacuated: 0,
  by_triage: { critical: 0, urgent: 0, moderate: 0, stable: 0 },
};

/**
 * The command-centre view of casualties registered in the field.
 *
 * Read-only by design. Records are authored on handsets, offline, and this
 * page shows what has reached the backend so far - it is a mirror of field
 * activity, never the place a casualty is created.
 */
export function VictimsPage() {
  const [search, setSearch] = useState("");
  const [triage, setTriage] = useState<TriageCategory | null>(null);
  const [status, setStatus] = useState<VictimStatus | null>(null);

  const { state, reload } = useVictims({ search, triage, status });
  const page = state.kind === "ready" ? state.page : null;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Victims</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Registered on field devices and uploaded when a link is available
          </p>
        </div>
        <StatusPill tone="info">Slice 2 — triage</StatusPill>
      </div>

      <TriageBoard board={page?.board ?? EMPTY_BOARD} />

      <Panel
        title="Casualty roster"
        subtitle="Most urgent first"
        actions={
          page ? (
            <span className="font-mono text-xs text-ink-500">
              {page.items.length} shown · {page.board.total} uploaded
            </span>
          ) : null
        }
      >
        <div className="flex flex-wrap gap-2 border-b border-navy-700 px-4 py-3">
          <label className="relative flex-1 min-w-56">
            <span className="sr-only">Search victims</span>
            <Search
              className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-ink-500"
              aria-hidden
            />
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search name, tag or injury"
              className="w-full rounded-sm border border-navy-600 bg-navy-900 py-1.5 pl-8 pr-3 text-sm text-ink-200 placeholder:text-ink-500"
            />
          </label>

          <label>
            <span className="sr-only">Filter by triage category</span>
            <select
              value={triage ?? ""}
              onChange={(event) => setTriage((event.target.value || null) as TriageCategory | null)}
              className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200"
            >
              <option value="">All triage</option>
              {TRIAGE_CATEGORIES.map((category) => (
                <option key={category} value={category}>
                  {category}
                </option>
              ))}
            </select>
          </label>

          <label>
            <span className="sr-only">Filter by status</span>
            <select
              value={status ?? ""}
              onChange={(event) => setStatus((event.target.value || null) as VictimStatus | null)}
              className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200"
            >
              <option value="">All statuses</option>
              {VICTIM_STATUSES.map((value) => (
                <option key={value} value={value}>
                  {STATUS_LABELS[value]}
                </option>
              ))}
            </select>
          </label>
        </div>

        {state.kind === "loading" && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">Loading roster…</p>
        )}

        {state.kind === "unreachable" && <BackendUnreachable onRetry={reload} />}

        {state.kind === "error" && (
          <p role="alert" className="px-4 py-8 text-center text-sm text-critical">
            {state.message}
          </p>
        )}

        {page && page.items.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">
            {page.board.total === 0
              ? "No victims have been uploaded from the field yet."
              : "No victims match this filter."}
          </p>
        )}

        {page && page.items.length > 0 && <VictimTable victims={page.items} />}
      </Panel>
    </div>
  );
}

function BackendUnreachable({ onRetry }: { onRetry: () => void }) {
  return (
    <div role="alert" className="flex flex-col items-center gap-2 px-4 py-8 text-center">
      <CloudOff className="size-5 text-elevated" aria-hidden />
      <p className="text-sm font-semibold text-ink-200">Coordination backend unreachable</p>
      <p className="max-w-md text-xs leading-relaxed text-ink-400">
        This affects the command centre only. Field devices continue to register and triage
        casualties in their own local storage and will upload them when a link returns.
      </p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-1 rounded-sm border border-navy-600 px-3 py-1 text-xs font-semibold text-ink-300 hover:bg-navy-800"
      >
        Retry
      </button>
    </div>
  );
}
