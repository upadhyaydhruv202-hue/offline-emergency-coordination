import { LogOut } from "lucide-react";
import { useEffect, useState } from "react";
import { ROLE_LABELS, type AuthenticatedUser } from "../../lib/api/auth";
import { env } from "../../lib/env";
import { StatusPill } from "../ui/StatusPill";

function useUtcClock(): string {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  return now.toISOString().slice(11, 19);
}

interface TopBarProps {
  user: AuthenticatedUser;
  onSignOut: () => void;
}

export function TopBar({ user, onSignOut }: TopBarProps) {
  const utc = useUtcClock();

  return (
    <header className="flex h-14 shrink-0 items-center gap-4 border-b border-navy-700 bg-navy-900 px-4">
      <div className="min-w-0">
        <p className="label-caps">Command centre</p>
        <p className="truncate text-sm font-medium text-ink-100">{env.commandCentreName}</p>
      </div>

      <div className="ml-auto flex items-center gap-4">
        <div className="hidden text-right sm:block">
          <p className="label-caps">UTC</p>
          <p className="font-mono text-sm tabular-nums text-ink-200">{utc}</p>
        </div>

        <StatusPill tone="nominal">Backend online</StatusPill>

        <div className="flex items-center gap-3 border-l border-navy-700 pl-4">
          <div className="text-right">
            <p className="text-sm font-medium text-ink-100">{user.full_name}</p>
            <p className="text-xs text-ink-500">{ROLE_LABELS[user.role]}</p>
          </div>
          <button
            type="button"
            onClick={onSignOut}
            className="rounded-sm border border-navy-600 p-1.5 text-ink-400 transition-colors hover:border-critical/50 hover:text-critical"
            aria-label="Sign out"
            title="Sign out"
          >
            <LogOut className="size-4" aria-hidden />
          </button>
        </div>
      </div>
    </header>
  );
}
