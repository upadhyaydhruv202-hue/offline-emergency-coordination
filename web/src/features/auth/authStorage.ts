const ACCESS_TOKEN_KEY = "drp.accessToken";
const REFRESH_TOKEN_KEY = "drp.refreshToken";

/**
 * localStorage is a deliberate Slice 1 choice: it survives a page reload during
 * a demo. Moving the refresh token to an httpOnly cookie is tracked as part of
 * the hardening slice.
 */
export const authStorage = {
  read(): { accessToken: string | null; refreshToken: string | null } {
    try {
      return {
        accessToken: localStorage.getItem(ACCESS_TOKEN_KEY),
        refreshToken: localStorage.getItem(REFRESH_TOKEN_KEY),
      };
    } catch {
      return { accessToken: null, refreshToken: null };
    }
  },

  write(accessToken: string, refreshToken: string): void {
    try {
      localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
      localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
    } catch {
      /* Private-browsing quota errors must not break sign-in. */
    }
  },

  clear(): void {
    try {
      localStorage.removeItem(ACCESS_TOKEN_KEY);
      localStorage.removeItem(REFRESH_TOKEN_KEY);
    } catch {
      /* no-op */
    }
  },
};
