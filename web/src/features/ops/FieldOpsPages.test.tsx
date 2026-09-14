import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { renderRoute } from "../../test/renderRoute";
import { seedStoredSession, stubApi, stubSignedInApi, TEST_USER } from "../../test/stubApi";

function jsonResponse(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
  } as Response;
}

describe("field operations pages", () => {
  it("lists uploaded incidents and sends the filter query", async () => {
    seedStoredSession();
    const fetchMock = stubApi((path) => {
      if (path.endsWith("/auth/me")) return jsonResponse(200, TEST_USER);
      if (path.includes("/incidents")) {
        return jsonResponse(200, {
          items: [
            {
              id: "inc-1",
              incident_code: "INC-SEED-001",
              title: "Ahmedabad Earthquake Response",
              disaster_type: "EARTHQUAKE",
              description: null,
              status: "ACTIVE",
              assigned_zone: "ZONE 04",
              latitude: 23.02,
              longitude: 72.57,
              created_by: "seed",
              last_modified_by: null,
              created_at: "2026-09-08T08:00:00Z",
              updated_at: "2026-09-08T08:00:00Z",
            },
          ],
          total: 1,
        });
      }
      return jsonResponse(404, { error: { code: "not_found", message: path } });
    });

    renderRoute("/incidents");
    const table = await screen.findByRole("table");
    expect(within(table).getByText("INC-SEED-001")).toBeInTheDocument();
    expect(table).toHaveTextContent("Ahmedabad Earthquake Response");

    await userEvent.selectOptions(screen.getByLabelText(/filter by status/i), "ACTIVE");
    expect(String(fetchMock.mock.calls.at(-1)?.[0])).toContain("status=ACTIVE");
  });

  it("shows an honest empty state when the backend has no field records", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/hazards");
    expect(
      await screen.findByText(/no hazards have been uploaded from the field yet/i),
    ).toBeInTheDocument();
  });

  it("distinguishes an unreachable backend from an empty roster", async () => {
    seedStoredSession();
    stubApi((path) => {
      if (path.endsWith("/auth/me")) return jsonResponse(200, TEST_USER);
      throw new TypeError("Failed to fetch");
    });
    renderRoute("/sos");
    expect(await screen.findByText(/coordination backend unreachable/i)).toBeInTheDocument();
  });
});
