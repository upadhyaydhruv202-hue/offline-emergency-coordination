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
      /active sos alerts/i,
      /open hazards/i,
      /blocked roads/i,
      /hospital capacity/i,
      /pending tasks/i,
    ]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
    expect(screen.getAllByText(/active incidents/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/critical victims/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/active responders/i).length).toBeGreaterThan(0);
  });

  it("reports command-centre counts from the snapshot", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/dashboard");

    expect(await screen.findAllByText(/ahmedabad earthquake response/i)).not.toHaveLength(0);
    expect(screen.getByText(/hospital capacity/i).closest("article")).toHaveTextContent("22");
  });

  it.each([
    ["/incidents", /incidents/i],
    ["/responders", /responders/i],
    ["/hazards", /hazards/i],
    ["/sos", /^SOS$/],
    ["/tasks", /tasks/i],
  ])("renders %s as a live operational page", async (path, heading) => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute(path);

    expect(await screen.findByRole("heading", { name: heading })).toBeInTheDocument();
    expect(screen.getByText(/slice 3 — field operations/i)).toBeInTheDocument();
    expect(screen.queryByText(/coming in development slice/i)).not.toBeInTheDocument();
  });

  it.each([
    ["/map", /operational map/i],
    ["/resources", /resources/i],
    ["/hospitals", /hospitals/i],
  ])("renders %s as a live command-centre page", async (path, heading) => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute(path);

    expect(await screen.findByRole("heading", { name: heading })).toBeInTheDocument();
    expect(screen.queryByText(/coming in development slice/i)).not.toBeInTheDocument();
  });

  it("renders settings as an explicit later-slice placeholder", async () => {
    seedStoredSession();
    stubSignedInApi();

    renderRoute("/settings");

    expect(await screen.findByRole("heading", { name: /settings/i })).toBeInTheDocument();
    expect(screen.getByText(/slice 6/i)).toBeInTheDocument();
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
