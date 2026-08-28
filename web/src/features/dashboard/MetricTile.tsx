import type { OperationalMetric } from "./operationalSnapshot";

const ACCENT_BAR: Record<string, string> = {
  critical: "bg-critical",
  high: "bg-high",
  elevated: "bg-elevated",
  nominal: "bg-nominal",
  info: "bg-accent-500",
  inactive: "bg-inactive",
};

export function MetricTile({ metric }: { metric: OperationalMetric }) {
  return (
    <article className="panel relative overflow-hidden p-4">
      <span
        className={`absolute inset-y-0 left-0 w-0.5 ${ACCENT_BAR[metric.tone]}`}
        aria-hidden
      />
      <div className="flex items-start justify-between gap-2">
        <p className="label-caps">{metric.label}</p>
        <span
          className="rounded-xs border border-navy-600 px-1 text-[10px] font-semibold text-ink-500"
          title={`Live data arrives in slice ${metric.source.slice(1)}`}
        >
          {metric.source}
        </span>
      </div>
      <p className="mt-2 font-mono text-3xl font-semibold tabular-nums text-ink-100">
        {metric.value}
      </p>
      <p className="mt-1 text-xs leading-relaxed text-ink-400">{metric.caption}</p>
    </article>
  );
}
