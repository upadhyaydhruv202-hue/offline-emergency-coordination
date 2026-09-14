import { screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { renderRoute } from "../../test/renderRoute";
import { seedStoredSession, stubSignedInApi } from "../../test/stubApi";

describe("synchronisation pages", () => {
  it("renders the sync dashboard as a live Slice 4 page", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/sync");
    expect(await screen.findByRole("heading", { name: /synchronisation/i })).toBeInTheDocument();
    expect(screen.getByText(/slice 4 — simulated sync/i)).toBeInTheDocument();
    expect(screen.getByText(/not mesh networking/i)).toBeInTheDocument();
    expect(screen.getByText(/Road R-12/)).toBeInTheDocument();
  });

  it("renders the conflict viewer with the development scenario", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/sync/conflicts");
    expect(await screen.findByRole("heading", { name: /conflict viewer/i })).toBeInTheDocument();
    expect(await screen.findByText(/ROAD BLOCKED/i)).toBeInTheDocument();
    expect(screen.getAllByText(/PARTIALLY ACCESSIBLE/i).length).toBeGreaterThan(0);
    expect(screen.getByText(/DEVICES CONVERGED/i)).toBeInTheDocument();
  });
});
