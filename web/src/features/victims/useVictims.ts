import { useCallback, useEffect, useState } from "react";
import { NetworkError } from "../../lib/api/client";
import {
  fetchVictimBoard,
  fetchVictims,
  type VictimBoard,
  type VictimPage,
  type VictimQuery,
} from "../../lib/api/victims";
import { authStorage } from "../auth/authStorage";

export type VictimsState =
  | { kind: "loading" }
  | { kind: "ready"; page: VictimPage }
  | { kind: "unreachable" }
  | { kind: "error"; message: string };

/**
 * Loads the victim roster for the command centre.
 *
 * An unreachable backend is a distinct state, not an error: the command centre
 * losing its uplink says nothing about the field devices, which keep
 * registering casualties into their own storage regardless.
 */
export function useVictims(query: VictimQuery): { state: VictimsState; reload: () => void } {
  const token = authStorage.read().accessToken;
  const [loaded, setLoaded] = useState<VictimsState>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);

  const { search, triage, status } = query;

  useEffect(() => {
    if (!token) return;

    const controller = new AbortController();

    fetchVictims(token, { search, triage, status }, controller.signal)
      .then((page) => setLoaded({ kind: "ready", page }))
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        if (cause instanceof NetworkError) {
          setLoaded({ kind: "unreachable" });
          return;
        }
        setLoaded({
          kind: "error",
          message: cause instanceof Error ? cause.message : "Could not load victims",
        });
      });

    return () => controller.abort();
  }, [token, search, triage, status, attempt]);

  const reload = useCallback(() => setAttempt((value) => value + 1), []);

  const state: VictimsState = token
    ? loaded
    : { kind: "error", message: "No session token available" };

  return { state, reload };
}

/**
 * Just the counts, for the dashboard tile.
 *
 * Returns null while loading and when the backend cannot be reached; the tile
 * shows a dash rather than a zero, because "no uplink" and "no casualties" are
 * very different things to put in front of a commander.
 */
export function useVictimBoard(): VictimBoard | null {
  const token = authStorage.read().accessToken;
  const [board, setBoard] = useState<VictimBoard | null>(null);

  useEffect(() => {
    if (!token) return;

    const controller = new AbortController();
    fetchVictimBoard(token, controller.signal)
      .then(setBoard)
      .catch(() => setBoard(null));

    return () => controller.abort();
  }, [token]);

  return board;
}
