import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import {
  fetchCurrentUser,
  login as loginRequest,
  type AuthenticatedUser,
} from "../../lib/api/auth";
import { AuthContext, type AuthStatus } from "./AuthContext";
import { authStorage } from "./authStorage";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthenticatedUser | null>(null);
  const [status, setStatus] = useState<AuthStatus>(() =>
    authStorage.read().accessToken ? "restoring" : "anonymous",
  );

  // Re-validate a stored token against the backend rather than trusting it.
  useEffect(() => {
    const { accessToken } = authStorage.read();
    if (!accessToken) return;

    let cancelled = false;

    fetchCurrentUser(accessToken)
      .then((profile) => {
        if (cancelled) return;
        setUser(profile);
        setStatus("authenticated");
      })
      .catch(() => {
        if (cancelled) return;
        authStorage.clear();
        setUser(null);
        setStatus("anonymous");
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    const result = await loginRequest(email, password);
    authStorage.write(result.access_token, result.refresh_token);
    setUser(result.user);
    setStatus("authenticated");
  }, []);

  const signOut = useCallback(() => {
    authStorage.clear();
    setUser(null);
    setStatus("anonymous");
  }, []);

  const value = useMemo(
    () => ({ status, user, signIn, signOut }),
    [status, user, signIn, signOut],
  );

  return <AuthContext value={value}>{children}</AuthContext>;
}
