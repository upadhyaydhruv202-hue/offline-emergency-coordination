import { CloudOff } from "lucide-react";

export function BackendUnreachable({ onRetry }: { onRetry: () => void }) {
  return (
    <div role="alert" className="flex flex-col items-center gap-2 px-4 py-8 text-center">
      <CloudOff className="size-5 text-elevated" aria-hidden />
      <p className="text-sm font-semibold text-ink-200">Coordination backend unreachable</p>
      <p className="max-w-md text-xs leading-relaxed text-ink-400">
        This affects the command centre only. Field devices continue to record incidents, SOS,
        hazards and tasks in their own local storage.
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
