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

  it("shows all five operational metrics", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/dashboard");
    await screen.findByRole("heading", { name: /operational overview/i });

    for (const label of [
      /active incidents/i,
      /active responders/i,
      /critical victims/i,
      /active hazards/i,
      /pending synchronisation/i,
    ]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
  });

  it.each([
    ["/incidents", /incidents/i, /slice 2/i],
    ["/responders", /responders/i, /slice 2/i],
    ["/victims", /victims/i, /slice 2/i],
    ["/map", /operational map/i, /slice 3/i],
    ["/resources", /resources/i, /slice 4/i],
    ["/settings", /settings/i, /slice 2/i],
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
