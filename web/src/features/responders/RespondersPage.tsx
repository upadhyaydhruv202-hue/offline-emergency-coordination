import { Search } from "lucide-react";
import { useState } from "react";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import { ROLE_LABELS, USER_ROLES, type UserRole } from "../../lib/api/auth";
import { fetchResponders } from "../../lib/api/responders";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { formatTimestamp } from "../ops/severity";
import { useOperationalQuery } from "../ops/useOperationalQuery";

export function RespondersPage() {
  const [search, setSearch] = useState("");
  const [role, setRole] = useState<UserRole | null>(null);
  const { state, reload } = useOperationalQuery(
    (token, signal) => fetchResponders(token, { search, role }, signal),
    [search, role],
    "Could not load responders",
  );
  const page = state.kind === "ready" ? state.page : null;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Responders</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Accounts that can hold a field device. Check-in state stays on the handset until Slice 4.
          </p>
        </div>
        <StatusPill tone="info">Slice 3 — field operations</StatusPill>
      </div>

      <CountBoard
        label="Responder summary"
        tiles={[
          { label: "Total", value: page?.total ?? 0, tone: "info" },
          { label: "Rescue", value: page?.items.filter((item) => item.role === "RESCUE_TEAM").length ?? 0, tone: "high" },
          { label: "Medical", value: page?.items.filter((item) => item.role === "MEDICAL_TEAM").length ?? 0, tone: "nominal" },
          { label: "Volunteer", value: page?.items.filter((item) => item.role === "VOLUNTEER").length ?? 0, tone: "elevated" },
        ]}
      />

      <Panel title="Roster" subtitle="By name">
        <div className="flex flex-wrap gap-2 border-b border-navy-700 px-4 py-3">
          <label className="relative min-w-56 flex-1">
            <span className="sr-only">Search responders</span>
            <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-ink-500" />
            <input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search name or email" className="w-full rounded-sm border border-navy-600 bg-navy-900 py-1.5 pl-8 pr-3 text-sm text-ink-200 placeholder:text-ink-500" />
          </label>
          <select aria-label="Filter by role" value={role ?? ""} onChange={(event) => setRole((event.target.value || null) as UserRole | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All roles</option>
            {USER_ROLES.map((value) => <option key={value} value={value}>{ROLE_LABELS[value]}</option>)}
          </select>
        </div>
        {state.kind === "loading" && <p className="px-4 py-8 text-center text-sm text-ink-500">Loading roster…</p>}
        {state.kind === "unreachable" && <BackendUnreachable onRetry={reload} />}
        {state.kind === "error" && <p role="alert" className="px-4 py-8 text-center text-sm text-critical">{state.message}</p>}
        {page && page.items.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">No responders match this filter.</p>
        )}
        {page && page.items.length > 0 && (
          <table className="w-full text-sm">
            <caption className="sr-only">Responder accounts</caption>
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="label-caps px-4 py-2">Name</th>
                <th className="label-caps px-4 py-2">Role</th>
                <th className="label-caps hidden px-4 py-2 md:table-cell">Email</th>
                <th className="label-caps px-4 py-2">Active</th>
                <th className="label-caps hidden px-4 py-2 text-right sm:table-cell">Created</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((responder) => (
                <tr key={responder.id} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2.5 font-medium text-ink-200">{responder.full_name}</td>
                  <td className="px-4 py-2.5 text-ink-300">{ROLE_LABELS[responder.role]}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 md:table-cell">{responder.email}</td>
                  <td className="px-4 py-2.5">
                    <StatusPill tone={responder.is_active ? "nominal" : "inactive"}>
                      {responder.is_active ? "Active" : "Inactive"}
                    </StatusPill>
                  </td>
                  <td className="hidden px-4 py-2.5 text-right font-mono text-xs text-ink-500 sm:table-cell">
                    {formatTimestamp(responder.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
