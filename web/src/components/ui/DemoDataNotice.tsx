import { FlaskConical } from "lucide-react";

/**
 * Every figure in Slice 1 is fabricated. This banner is mandatory on any view
 * that shows one - a judge or responder must never mistake it for live data.
 */
export function DemoDataNotice({ children }: { children?: React.ReactNode }) {
  return (
    <div
      role="note"
      className="flex items-start gap-2.5 rounded-md border border-elevated/30 bg-elevated/8 px-3.5 py-2.5"
    >
      <FlaskConical className="mt-0.5 size-4 shrink-0 text-elevated" aria-hidden />
      <p className="text-xs leading-relaxed text-ink-300">
        <span className="font-semibold uppercase tracking-wider text-elevated">Demo data</span>
        {" — "}
        {children ??
          "every figure on this page is hard-coded. Live incident, responder and synchronisation feeds arrive in later slices."}
      </p>
    </div>
  );
}
