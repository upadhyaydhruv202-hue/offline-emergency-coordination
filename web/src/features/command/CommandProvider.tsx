import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { NetworkError } from "../../lib/api/client";
import { fetchCommandSnapshot, type CommandSnapshot } from "../../lib/api/command";
import { authStorage } from "../auth/authStorage";
import { CommandStatusContext, type ConnectionState } from "./commandStatus";

const POLL_MS = 30_000;

export function CommandProvider({ children }: { children: ReactNode }) {
  const token = authStorage.read().accessToken;
  const [snapshot, setSnapshot] = useState<CommandSnapshot | null>(null);
  const [connection, setConnection] = useState<ConnectionState>("loading");
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const hasData = useRef(false);

  const load = useCallback(async (signal: AbortSignal) => {
    if (!token) return;
    try {
      const next = await fetchCommandSnapshot(token, signal);
      hasData.current = true;
      setSnapshot(next);
      setConnection("live");
      setError(null);
    } catch (cause) {
      if (signal.aborted) return;
      setConnection(hasData.current ? "stale" : "offline");
      if (cause instanceof NetworkError) {
        setError("Data may be stale — connection unavailable");
        return;
      }
      setError(cause instanceof Error ? cause.message : "Unable to load command picture");
    }
  }, [token]);

  useEffect(() => {
    const controller = new AbortController();
    void load(controller.signal);
    const timer = window.setInterval(() => void load(new AbortController().signal), POLL_MS);
    return () => {
      controller.abort();
      window.clearInterval(timer);
    };
  }, [attempt, load]);

  const value = useMemo(
    () => ({
      snapshot,
      connection,
      lastUpdatedAt: snapshot?.generated_at ?? null,
      error,
      reload: () => setAttempt((n) => n + 1),
    }),
    [snapshot, connection, error],
  );

  return <CommandStatusContext.Provider value={value}>{children}</CommandStatusContext.Provider>;
}
