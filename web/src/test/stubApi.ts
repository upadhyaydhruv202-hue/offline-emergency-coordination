import { vi } from "vitest";
import type { AuthenticatedUser, LoginResponse } from "../lib/api/auth";

export const TEST_USER: AuthenticatedUser = {
  id: "11111111-2222-3333-4444-555555555555",
  email: "commander@drp.example",
  full_name: "A. Rathore",
  role: "INCIDENT_COMMANDER",
  is_active: true,
  created_at: "2026-08-01T00:00:00Z",
};

export const TEST_LOGIN_RESPONSE: LoginResponse = {
  access_token: "test.access.token",
  refresh_token: "test.refresh.token",
  token_type: "bearer",
  expires_in: 3600,
  user: TEST_USER,
};

function jsonResponse(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
  } as Response;
}

type Handler = (path: string) => Response;

/** Replaces global fetch with a router over the API paths used by the app. */
export function stubApi(handler: Handler) {
  const fetchMock = vi.fn(async (input: RequestInfo | URL) => handler(String(input)));
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

export function stubSignedInApi() {
  return stubApi((path) => {
    if (path.endsWith("/auth/me")) return jsonResponse(200, TEST_USER);
    if (path.endsWith("/auth/login")) return jsonResponse(200, TEST_LOGIN_RESPONSE);
    return jsonResponse(404, { error: { code: "not_found", message: "No stub for " + path } });
  });
}

export function stubLoginFailure(status: number, code: string, message: string) {
  return stubApi(() => jsonResponse(status, { error: { code, message } }));
}

export function stubUnreachableApi() {
  const fetchMock = vi.fn(async () => {
    throw new TypeError("Failed to fetch");
  });
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

/** Puts a token in storage so AuthProvider attempts a session restore. */
export function seedStoredSession() {
  localStorage.setItem("drp.accessToken", TEST_LOGIN_RESPONSE.access_token);
  localStorage.setItem("drp.refreshToken", TEST_LOGIN_RESPONSE.refresh_token);
}
