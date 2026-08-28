import { createContext } from "react";
import type { AuthenticatedUser } from "../../lib/api/auth";

export type AuthStatus = "restoring" | "authenticated" | "anonymous";

export interface AuthContextValue {
  status: AuthStatus;
  user: AuthenticatedUser | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => void;
}

export const AuthContext = createContext<AuthContextValue | null>(null);
