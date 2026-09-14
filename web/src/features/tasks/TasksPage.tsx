import { Search } from "lucide-react";
import { useState } from "react";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/ui/StatusPill";
import {
  TASK_PRIORITIES,
  TASK_STATUSES,
  TASK_STATUS_LABELS,
  fetchTasks,
  type TaskPriority,
  type TaskStatus,
} from "../../lib/api/tasks";
import { BackendUnreachable } from "../ops/BackendUnreachable";
import { CountBoard } from "../ops/CountBoard";
import { formatTimestamp, SEVERITY_TONE } from "../ops/severity";
import { useOperationalQuery } from "../ops/useOperationalQuery";

export function TasksPage() {
  const [search, setSearch] = useState("");
  const [priority, setPriority] = useState<TaskPriority | null>(null);
  const [status, setStatus] = useState<TaskStatus | null>(null);
  const { state, reload } = useOperationalQuery(
    (token, signal) => fetchTasks(token, { search, priority, status }, signal),
    [search, priority, status],
    "Could not load tasks",
  );
  const page = state.kind === "ready" ? state.page : null;

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-ink-100">Tasks</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            Work recorded on field devices. Assignment from command arrives with Slice 4.
          </p>
        </div>
        <StatusPill tone="info">Slice 3 — field operations</StatusPill>
      </div>

      <CountBoard
        label="Task summary"
        tiles={[
          { label: "Total", value: page?.total ?? 0, tone: "info" },
          { label: "CRITICAL", value: page?.items.filter((item) => item.priority === "CRITICAL").length ?? 0, tone: "critical" },
          { label: "In progress", value: page?.items.filter((item) => item.status === "IN_PROGRESS").length ?? 0, tone: "elevated" },
          { label: "Pending", value: page?.items.filter((item) => item.status === "PENDING").length ?? 0, tone: "inactive" },
        ]}
      />

      <Panel title="Task board" subtitle="Highest priority first">
        <div className="flex flex-wrap gap-2 border-b border-navy-700 px-4 py-3">
          <label className="relative min-w-56 flex-1">
            <span className="sr-only">Search tasks</span>
            <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-ink-500" />
            <input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search title or code" className="w-full rounded-sm border border-navy-600 bg-navy-900 py-1.5 pl-8 pr-3 text-sm text-ink-200 placeholder:text-ink-500" />
          </label>
          <select aria-label="Filter by priority" value={priority ?? ""} onChange={(event) => setPriority((event.target.value || null) as TaskPriority | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All priorities</option>
            {TASK_PRIORITIES.map((value) => <option key={value} value={value}>{value}</option>)}
          </select>
          <select aria-label="Filter by status" value={status ?? ""} onChange={(event) => setStatus((event.target.value || null) as TaskStatus | null)} className="rounded-sm border border-navy-600 bg-navy-900 px-3 py-1.5 text-sm text-ink-200">
            <option value="">All statuses</option>
            {TASK_STATUSES.map((value) => <option key={value} value={value}>{TASK_STATUS_LABELS[value]}</option>)}
          </select>
        </div>
        {state.kind === "loading" && <p className="px-4 py-8 text-center text-sm text-ink-500">Loading tasks…</p>}
        {state.kind === "unreachable" && <BackendUnreachable onRetry={reload} />}
        {state.kind === "error" && <p role="alert" className="px-4 py-8 text-center text-sm text-critical">{state.message}</p>}
        {page && page.items.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-ink-500">
            {page.total === 0 ? "No tasks have been uploaded from the field yet." : "No tasks match this filter."}
          </p>
        )}
        {page && page.items.length > 0 && (
          <table className="w-full text-sm">
            <caption className="sr-only">Tasks recorded on field devices</caption>
            <thead>
              <tr className="border-b border-navy-700 text-left">
                <th className="label-caps px-4 py-2">Priority</th>
                <th className="label-caps px-4 py-2">Code</th>
                <th className="label-caps px-4 py-2">Title</th>
                <th className="label-caps hidden px-4 py-2 lg:table-cell">Location</th>
                <th className="label-caps px-4 py-2">Status</th>
                <th className="label-caps hidden px-4 py-2 text-right sm:table-cell">Updated</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((task) => (
                <tr key={task.id} className="border-b border-navy-800 last:border-0">
                  <td className="px-4 py-2.5"><StatusPill tone={SEVERITY_TONE[task.priority]}>{task.priority}</StatusPill></td>
                  <td className="px-4 py-2.5 font-mono text-xs text-ink-300">{task.task_code}</td>
                  <td className="px-4 py-2.5 font-medium text-ink-200">{task.title}</td>
                  <td className="hidden px-4 py-2.5 text-ink-400 lg:table-cell">{task.location ?? "—"}</td>
                  <td className="px-4 py-2.5"><StatusPill tone={SEVERITY_TONE[task.status] ?? "inactive"}>{TASK_STATUS_LABELS[task.status]}</StatusPill></td>
                  <td className="hidden px-4 py-2.5 text-right font-mono text-xs text-ink-500 sm:table-cell">{formatTimestamp(task.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
