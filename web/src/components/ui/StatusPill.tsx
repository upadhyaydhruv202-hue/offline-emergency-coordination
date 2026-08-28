export type StatusTone = "critical" | "high" | "elevated" | "nominal" | "inactive" | "info";

const TONE_CLASSES: Record<StatusTone, string> = {
  critical: "border-critical/40 bg-critical/10 text-critical",
  high: "border-high/40 bg-high/10 text-high",
  elevated: "border-elevated/40 bg-elevated/10 text-elevated",
  nominal: "border-nominal/40 bg-nominal/10 text-nominal",
  inactive: "border-navy-600 bg-navy-800 text-ink-400",
  info: "border-accent-500/40 bg-accent-500/10 text-accent-300",
};

const DOT_CLASSES: Record<StatusTone, string> = {
  critical: "bg-critical",
  high: "bg-high",
  elevated: "bg-elevated",
  nominal: "bg-nominal",
  inactive: "bg-inactive",
  info: "bg-accent-400",
};

interface StatusPillProps {
  tone: StatusTone;
  children: React.ReactNode;
  showDot?: boolean;
}

export function StatusPill({ tone, children, showDot = true }: StatusPillProps) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-sm border px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider ${TONE_CLASSES[tone]}`}
    >
      {showDot && <span className={`size-1.5 rounded-full ${DOT_CLASSES[tone]}`} aria-hidden />}
      {children}
    </span>
  );
}
