import { Construction } from "lucide-react";

interface PlaceholderPageProps {
  title: string;
  slice: string;
  summary: string;
  scope: string[];
}

/**
 * Honest stand-in for a module that has not been built. It states the slice
 * that will deliver it and what that slice covers - it never fakes the feature.
 */
export function PlaceholderPage({ title, slice, summary, scope }: PlaceholderPageProps) {
  return (
    <div className="mx-auto max-w-3xl">
      <div className="panel p-6">
        <div className="flex items-center gap-3">
          <Construction className="size-5 text-elevated" aria-hidden />
          <h1 className="text-lg font-semibold text-ink-100">{title}</h1>
        </div>

        <p className="mt-4 text-sm leading-relaxed text-ink-300">
          Coming in development slice {slice}. {summary}
        </p>

        <div className="mt-6 border-t border-navy-700 pt-4">
          <p className="label-caps mb-2">Planned scope</p>
          <ul className="space-y-1.5 text-sm text-ink-400">
            {scope.map((item) => (
              <li key={item} className="flex gap-2">
                <span className="text-ink-500" aria-hidden>
                  —
                </span>
                {item}
              </li>
            ))}
          </ul>
        </div>

        <p className="mt-6 text-xs leading-relaxed text-ink-500">
          Nothing on this page is simulated. The module is genuinely not implemented in the Slice 1
          foundation build.
        </p>
      </div>
    </div>
  );
}
