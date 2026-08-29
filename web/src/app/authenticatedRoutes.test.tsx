import { screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { renderRoute } from "../test/renderRoute";
import { seedStoredSession, stubSignedInApi } from "../test/stubApi";

describe("authenticated routing", () => {
  it("restores a stored session and renders the dashboard", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/dashboard");

    expect(
      await screen.findByRole("heading", { name: /operational overview/i }),
    ).toBeInTheDocument();
  });

  it("labels every dashboard figure as demo data", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/dashboard");

    expect(await screen.findByRole("note")).toHaveTextContent(/demo data/i);
  });

  it("shows every operational metric", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/dashboard");
    await screen.findByRole("heading", { name: /operational overview/i });

    for (const label of [
      /registered victims/i,
      /critical victims/i,
      /active incidents/i,
      /active responders/i,
      /active hazards/i,
      /pending synchronisation/i,
    ]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
  });

  it("reports victim counts from the backend rather than a fixed figure", async () => {
    seedStoredSession();
    stubSignedInApi(() => ({
      items: [],
      board: {
        total: 12,
        open_cases: 9,
        evacuated: 3,
        by_triage: { critical: 4, urgent: 3, moderate: 2, stable: 3 },
      },
      total: 12,
    }));

    renderRoute("/dashboard");

    const caption = await screen.findByText("9 open · 3 evacuated");
    expect(caption.closest("article")).toHaveTextContent("12");
  });

  it.each([
    ["/incidents", /incidents/i, /slice 3/i],
    ["/responders", /responders/i, /slice 3/i],
    ["/map", /operational map/i, /slice 3/i],
    ["/resources", /resources/i, /slice 4/i],
    ["/settings", /settings/i, /slice 4/i],
  ])("renders %s as an explicit placeholder", async (path, heading, slice) => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute(path);

    expect(await screen.findByRole("heading", { name: heading })).toBeInTheDocument();
    expect(screen.getByText(slice)).toBeInTheDocument();
  });

  it("renders a not-found page for an unknown route", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/no-such-module");

    expect(await screen.findByRole("heading", { name: /route not found/i })).toBeInTheDocument();
  });

  it("signs the user out and returns to the login screen", async () => {
    seedStoredSession();
    stubSignedInApi();

    const { default: userEvent } = await import("@testing-library/user-event");
    renderRoute("/dashboard");
    await screen.findByRole("heading", { name: /operational overview/i });

    await userEvent.setup().click(screen.getByRole("button", { name: /sign out/i }));

    expect(
      await screen.findByRole("heading", { name: /command centre sign-in/i }),
    ).toBeInTheDocument();
    expect(localStorage.getItem("drp.accessToken")).toBeNull();
  });
});
