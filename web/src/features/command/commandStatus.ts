import { createContext, useContext } from "react";
import type { CommandSnapshot } from "../../lib/api/command";

export type ConnectionState = "live" | "stale" | "offline" | "loading";

export interface CommandStatus {
  snapshot: CommandSnapshot | null;
  connection: ConnectionState;
  lastUpdatedAt: string | null;
  error: string | null;
  reload: () => void;
}

export const CommandStatusContext = createContext<CommandStatus | null>(null);

export function useCommandStatus(): CommandStatus {
  const value = useContext(CommandStatusContext);
  if (!value) {
    return {
      snapshot: null,
      connection: "loading",
      lastUpdatedAt: null,
      error: null,
      reload: () => undefined,
    };
  }
  return value;
}
