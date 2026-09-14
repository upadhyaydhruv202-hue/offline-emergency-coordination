import { vi } from "vitest";
import type { AuthenticatedUser, LoginResponse } from "../lib/api/auth";
import type { Victim, VictimBoard, VictimPage } from "../lib/api/victims";

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

export function makeVictim(overrides: Partial<Victim> = {}): Victim {
  return {
    id: "aaaaaaaa-0000-0000-0000-000000000001",
    temporary_id: "V-8C1F-001",
    name: "A. Sharma",
    age: 41,
    age_group: "ADULT",
    gender: "FEMALE",
    medical_condition: null,
    injury_type: "Crush injury to left leg",
    triage_category: "CRITICAL",
    priority: 0,
    assistance_required: null,
    status: "REGISTERED",
    latitude: null,
    longitude: null,
    created_by: "local-session-1",
    created_at: "2026-08-29T08:00:00Z",
    updated_at: "2026-08-29T08:05:00Z",
    ...overrides,
  };
}

export function makeBoard(overrides: Partial<VictimBoard> = {}): VictimBoard {
  return {
    total: 0,
    open_cases: 0,
    evacuated: 0,
    by_triage: { critical: 0, urgent: 0, moderate: 0, stable: 0 },
    ...overrides,
  };
}

/**
 * Routes the auth and victim endpoints.
 *
 * `victims` is a function of the request path so a test can assert on the
 * query string the page actually sent.
 */
export function stubSignedInApi(victims?: (path: string) => VictimPage) {
  return stubApi((path) => {
    if (path.endsWith("/auth/me")) return jsonResponse(200, TEST_USER);
    if (path.endsWith("/auth/login")) return jsonResponse(200, TEST_LOGIN_RESPONSE);
    if (path.includes("/victims/board")) {
      return jsonResponse(200, victims ? victims(path).board : makeBoard());
    }
    if (path.includes("/victims")) {
      const page = victims?.(path) ?? { items: [], board: makeBoard(), total: 0 };
      return jsonResponse(200, page);
    }
    if (path.includes("/incidents/board")) {
      return jsonResponse(200, { total: 0, by_status: { active: 0, paused: 0, resolved: 0 } });
    }
    if (path.includes("/incidents")) {
      return jsonResponse(200, { items: [], total: 0 });
    }
    if (path.includes("/hazards/board")) {
      return jsonResponse(200, {
        total: 0,
        by_severity: { critical: 0, high: 0, medium: 0, low: 0 },
        by_status: { reported: 0, verified: 0, resolved: 0 },
      });
    }
    if (path.includes("/hazards")) {
      return jsonResponse(200, { items: [], total: 0 });
    }
    if (path.includes("/sos/board")) {
      return jsonResponse(200, {
        total: 0,
        by_priority: { critical: 0, high: 0, medium: 0 },
        by_status: { created: 0, acknowledged: 0, resolved: 0 },
      });
    }
    if (path.includes("/sos")) {
      return jsonResponse(200, { items: [], total: 0 });
    }
    if (path.includes("/tasks/board")) {
      return jsonResponse(200, {
        total: 0,
        open_tasks: 0,
        by_status: { pending: 0, accepted: 0, in_progress: 0, completed: 0, cancelled: 0 },
      });
    }
    if (path.includes("/tasks")) {
      return jsonResponse(200, { items: [], total: 0 });
    }
    if (path.includes("/responders")) {
      return jsonResponse(200, { items: [TEST_USER], total: 1 });
    }
    if (path.includes("/sync/demo-scenario")) {
      return jsonResponse(200, {
        kind: "DEVELOPMENT_SCENARIO",
        transport: "SIMULATED",
        incident: "Ahmedabad Earthquake Response",
        zone: "04",
        entity: "Road R-12",
        entity_id: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012",
        device_a: {
          device_id: "DRP-ALPHA001",
          actor: "Responder Alpha",
          type: "ROAD_BLOCKED",
          severity: "HIGH",
        },
        device_b: {
          device_id: "DRP-BRAVO001",
          actor: "Responder Bravo",
          type: "PARTIALLY_ACCESSIBLE",
          severity: "MEDIUM",
        },
        resolution: "LAST_WRITER_WINS",
        winner_device: "DRP-BRAVO001",
        final_state: { type: "PARTIALLY_ACCESSIBLE", severity: "MEDIUM" },
        note: "Deterministic conflict resolution. This is not mesh networking.",
      });
    }
    if (path.includes("/sync/status")) {
      return jsonResponse(200, {
        pending: 0,
        acknowledged: 2,
        failed: 0,
        conflicts: 1,
        last_push_at: null,
        note: "Peer ingest only. This is not live mesh networking.",
      });
    }
    if (path.includes("/sync/conflicts")) {
      return jsonResponse(200, []);
    }
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
