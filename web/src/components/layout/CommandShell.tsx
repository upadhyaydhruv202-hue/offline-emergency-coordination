import { Radio } from "lucide-react";
import { Outlet } from "react-router-dom";
import { useAuth } from "../../features/auth/useAuth";
import { SidebarNav } from "./SidebarNav";
import { TopBar } from "./TopBar";

export function CommandShell() {
  const { user, signOut } = useAuth();

  // ProtectedRoute guarantees a user before this renders.
  if (!user) return null;

  return (
    <div className="flex h-screen overflow-hidden bg-navy-950">
      <aside className="hidden w-60 shrink-0 flex-col border-r border-navy-700 bg-navy-900 md:flex">
        <div className="flex h-14 items-center gap-2.5 border-b border-navy-700 px-4">
          <Radio className="size-5 text-accent-400" aria-hidden />
          <div className="leading-tight">
            <p className="text-sm font-semibold tracking-wide text-ink-100">DRP</p>
            <p className="text-[10px] uppercase tracking-[0.16em] text-ink-500">Coordination</p>
          </div>
        </div>

        <SidebarNav />

        <div className="border-t border-navy-700 px-4 py-3">
          <p className="label-caps">Build</p>
          <p className="font-mono text-xs text-ink-400">slice-2 · victims and triage</p>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar user={user} onSignOut={signOut} />
        <main className="flex-1 overflow-y-auto p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
