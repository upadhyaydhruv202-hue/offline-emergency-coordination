import type { StatusTone } from "../../components/ui/StatusPill";
import type { OperationalMetric } from "./operationalSnapshot";

const ACCENT_BAR: Record<string, string> = {
  critical: "bg-critical",
  high: "bg-high",
  elevated: "bg-elevated",
  nominal: "bg-nominal",
  info: "bg-accent-500",
  inactive: "bg-inactive",
};

interface TileProps {
  label: string;
  value: number | string;
  caption: string;
  tone: StatusTone;
  /** Slice tag for a fabricated figure; omitted once the number is real. */
  source?: string;
}

export function Tile({ label, value, caption, tone, source }: TileProps) {
  return (
    <article className="panel relative overflow-hidden p-4">
      <span className={`absolute inset-y-0 left-0 w-0.5 ${ACCENT_BAR[tone]}`} aria-hidden />
      <div className="flex items-start justify-between gap-2">
        <p className="label-caps">{label}</p>
        {source ? (
          <span
            className="rounded-xs border border-navy-600 px-1 text-[10px] font-semibold text-ink-500"
            title={`Live data arrives in slice ${source.slice(1)}`}
          >
            {source}
          </span>
        ) : (
          <span className="rounded-xs border border-nominal/40 px-1 text-[10px] font-semibold text-nominal">
            LIVE
          </span>
        )}
      </div>
      <p className="mt-2 font-mono text-3xl font-semibold tabular-nums text-ink-100">{value}</p>
      <p className="mt-1 text-xs leading-relaxed text-ink-400">{caption}</p>
    </article>
  );
}

export function MetricTile({ metric }: { metric: OperationalMetric }) {
  return (
    <Tile
      label={metric.label}
      value={metric.value}
      caption={metric.caption}
      tone={metric.tone}
      source={metric.source}
    />
  );
}
