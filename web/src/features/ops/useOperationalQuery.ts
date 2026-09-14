import { useCallback, useEffect, useState } from "react";
import { NetworkError } from "../../lib/api/client";
import { authStorage } from "../auth/authStorage";

export type QueryState<T> =
  | { kind: "loading" }
  | { kind: "ready"; page: T }
  | { kind: "unreachable" }
  | { kind: "error"; message: string };

export function useOperationalQuery<T>(
  load: (token: string, signal: AbortSignal) => Promise<T>,
  deps: unknown[],
  emptyMessage: string,
): { state: QueryState<T>; reload: () => void } {
  const token = authStorage.read().accessToken;
  const [loaded, setLoaded] = useState<QueryState<T>>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (!token) return;
    const controller = new AbortController();
    load(token, controller.signal)
      .then((page) => setLoaded({ kind: "ready", page }))
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        if (cause instanceof NetworkError) {
          setLoaded({ kind: "unreachable" });
          return;
        }
        setLoaded({
          kind: "error",
          message: cause instanceof Error ? cause.message : emptyMessage,
        });
      });
    return () => controller.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, attempt, ...deps]);

  const reload = useCallback(() => setAttempt((value) => value + 1), []);
  const state: QueryState<T> = token
    ? loaded
    : { kind: "error", message: "No session token available" };
  return { state, reload };
}

export function useBoard<T>(load: (token: string, signal: AbortSignal) => Promise<T>): T | null {
  const token = authStorage.read().accessToken;
  const [board, setBoard] = useState<T | null>(null);

  useEffect(() => {
    if (!token) return;
    const controller = new AbortController();
    load(token, controller.signal)
      .then(setBoard)
      .catch(() => setBoard(null));
    return () => controller.abort();
  }, [token, load]);

  return board;
}
