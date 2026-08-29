import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import type { VictimPage } from "../../lib/api/victims";
import { renderRoute } from "../../test/renderRoute";
import {
  makeBoard,
  makeVictim,
  seedStoredSession,
  stubApi,
  stubSignedInApi,
  stubUnreachableApi,
  TEST_USER,
} from "../../test/stubApi";

const ROSTER: VictimPage = {
  items: [
    makeVictim({ id: "id-critical", name: "A. Sharma", triage_category: "CRITICAL", priority: 0 }),
    makeVictim({
      id: "id-urgent",
      temporary_id: "V-8C1F-002",
      name: "R. Verma",
      triage_category: "URGENT",
      priority: 1,
      status: "AWAITING_EVACUATION",
    }),
    makeVictim({
      id: "id-stable",
      temporary_id: "V-8C1F-003",
      name: null,
      triage_category: "STABLE",
      priority: 3,
      status: "EVACUATED",
    }),
  ],
  board: makeBoard({
    total: 3,
    open_cases: 2,
    evacuated: 1,
    by_triage: { critical: 1, urgent: 1, moderate: 0, stable: 1 },
  }),
  total: 3,
};

function openVictims(page: VictimPage = ROSTER) {
  seedStoredSession();
  stubSignedInApi(() => page);
  renderRoute("/victims");
}

describe("victims page", () => {
  it("shows the count for every triage category, including empty ones", async () => {
    openVictims();

    await screen.findByRole("table");
    const board = screen.getByRole("region", { name: /triage summary/i });
    const tileFor = (label: string) => within(board).getByText(label).closest("article");

    expect(tileFor("Total victims")).toHaveTextContent("3");
    expect(tileFor("CRITICAL")).toHaveTextContent("1");
    expect(tileFor("URGENT")).toHaveTextContent("1");
    expect(tileFor("MODERATE")).toHaveTextContent("0");
    expect(tileFor("STABLE")).toHaveTextContent("1");
  });

  it("lists the roster with tag, triage and status", async () => {
    openVictims();

    const table = await screen.findByRole("table");
    const rows = within(table).getAllByRole("row").slice(1);

    expect(rows).toHaveLength(3);
    expect(rows[0]).toHaveTextContent("V-8C1F-001");
    expect(rows[0]).toHaveTextContent("A. Sharma");
    expect(rows[0]).toHaveTextContent("CRITICAL");
    expect(rows[1]).toHaveTextContent("Awaiting evacuation");
  });

  it("keeps the backend's severity ordering", async () => {
    openVictims();

    const table = await screen.findByRole("table");
    const rows = within(table).getAllByRole("row").slice(1);

    expect(rows.map((row) => row.textContent?.match(/CRITICAL|URGENT|MODERATE|STABLE/)?.[0])).toEqual(
      ["CRITICAL", "URGENT", "STABLE"],
    );
  });

  it("names an unidentified casualty rather than leaving the cell blank", async () => {
    openVictims();

    const table = await screen.findByRole("table");

    expect(within(table).getByText(/unidentified/i)).toBeInTheDocument();
  });

  it("sends the chosen triage filter to the backend", async () => {
    seedStoredSession();
    const fetchMock = stubSignedInApi(() => ROSTER);
    renderRoute("/victims");
    await screen.findByRole("table");

    await userEvent.setup().selectOptions(
      screen.getByRole("combobox", { name: /triage/i }),
      "CRITICAL",
    );

    const requested = fetchMock.mock.calls.map((call) => String(call[0]));
    expect(requested.some((path) => path.includes("triage=CRITICAL"))).toBe(true);
  });

  it("sends the search term to the backend", async () => {
    seedStoredSession();
    const fetchMock = stubSignedInApi(() => ROSTER);
    renderRoute("/victims");
    await screen.findByRole("table");

    await userEvent.setup().type(screen.getByRole("searchbox", { name: /search/i }), "sharma");

    const requested = fetchMock.mock.calls.map((call) => String(call[0]));
    expect(requested.some((path) => path.includes("search=sharma"))).toBe(true);
  });

  it("says nothing has been uploaded rather than showing an empty table", async () => {
    openVictims({ items: [], board: makeBoard(), total: 0 });

    expect(await screen.findByText(/no victims have been uploaded/i)).toBeInTheDocument();
  });

  it("distinguishes an empty filter result from an empty roster", async () => {
    openVictims({ items: [], board: makeBoard({ total: 7, open_cases: 7 }), total: 0 });

    expect(await screen.findByText(/no victims match this filter/i)).toBeInTheDocument();
  });

  it("explains that an unreachable backend does not stop field registration", async () => {
    seedStoredSession();
    stubApi((path) => {
      if (path.endsWith("/auth/me")) {
        return { ok: true, status: 200, json: async () => TEST_USER } as Response;
      }
      throw new TypeError("Failed to fetch");
    });

    renderRoute("/victims");

    expect(await screen.findByText(/backend unreachable/i)).toBeInTheDocument();
    expect(screen.getByText(/field devices continue to register/i)).toBeInTheDocument();
  });

  it("survives the command centre having no uplink at all", async () => {
    seedStoredSession();
    stubUnreachableApi();

    renderRoute("/victims");

    // No session can be restored either, so this falls back to the login screen
    // rather than rendering a half-populated roster.
    expect(await screen.findByRole("heading", { name: /command centre sign-in/i })).toBeInTheDocument();
  });
});
