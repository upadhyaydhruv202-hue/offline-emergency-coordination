import type { StatusTone } from "../../components/ui/StatusPill";

interface Tile {
  label: string;
  value: number;
  caption?: string;
  tone: StatusTone;
}

const BAR: Record<StatusTone, string> = {
  critical: "bg-critical",
  high: "bg-high",
  elevated: "bg-elevated",
  nominal: "bg-nominal",
  inactive: "bg-inactive",
  info: "bg-accent-500",
};

export function CountBoard({
  label,
  tiles,
}: {
  label: string;
  tiles: Tile[];
}) {
  return (
    <section
      aria-label={label}
      className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
    >
      {tiles.map((tile) => (
        <article key={tile.label} className="panel relative overflow-hidden p-4">
          <span className={`absolute inset-y-0 left-0 w-0.5 ${BAR[tile.tone]}`} aria-hidden />
          <p className="label-caps">{tile.label}</p>
          <p className="mt-2 font-mono text-3xl font-semibold tabular-nums text-ink-100">
            {tile.value}
          </p>
          {tile.caption ? (
            <p className="mt-1 text-xs leading-relaxed text-ink-400">{tile.caption}</p>
          ) : null}
        </article>
      ))}
    </section>
  );
}
