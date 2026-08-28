import { Loader2 } from "lucide-react";
import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../features/auth/useAuth";

export function ProtectedRoute() {
  const { status } = useAuth();
  const location = useLocation();

  if (status === "restoring") {
    return (
      <div className="flex h-screen items-center justify-center" role="status" aria-live="polite">
        <Loader2 className="size-5 animate-spin text-accent-400" aria-hidden />
        <span className="ml-2 text-sm text-ink-400">Restoring session…</span>
      </div>
    );
  }

  if (status === "anonymous") {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  return <Outlet />;
}
