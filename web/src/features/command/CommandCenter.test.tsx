import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { renderRoute } from "../../test/renderRoute";
import { seedStoredSession, stubSignedInApi, stubSignedInSnapshotFailure } from "../../test/stubApi";

describe("command centre slice 5", () => {
  it("loads dashboard KPIs from the snapshot", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/dashboard");
    expect(await screen.findByRole("heading", { name: /operational overview/i })).toBeInTheDocument();
    expect(await screen.findAllByText(/ahmedabad earthquake response/i)).not.toHaveLength(0);
    expect(screen.getAllByText(/active incidents/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/simulated sync/i).length).toBeGreaterThan(0);
  });

  it("renders the operational map and filters markers", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/map");
    expect(await screen.findByRole("heading", { name: /operational map/i })).toBeInTheDocument();
    expect(await screen.findByText("HZ-R12")).toBeInTheDocument();
    await userEvent.selectOptions(screen.getByLabelText(/filter hazards/i), "FIRE");
    expect(screen.queryByText("HZ-R12")).not.toBeInTheDocument();
  });

  it("loads hospital status from snapshot facilities", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/hospitals");
    expect(await screen.findByRole("heading", { name: /hospitals/i })).toBeInTheDocument();
    expect(await screen.findByText(/civil hospital ahmedabad/i)).toBeInTheDocument();
    expect(screen.getByText("22")).toBeInTheDocument();
  });

  it("shows conflict information on the dashboard", async () => {
    seedStoredSession();
    stubSignedInApi();
    renderRoute("/dashboard");
    expect(await screen.findByText(/conflict viewer/i)).toBeInTheDocument();
    expect(screen.getAllByText(/simulated sync/i).length).toBeGreaterThan(0);
  });

  it("represents unreachable snapshot as offline", async () => {
    seedStoredSession();
    stubSignedInSnapshotFailure();
    renderRoute("/dashboard");
    expect(await screen.findByText(/coordination backend unreachable/i)).toBeInTheDocument();
  });
});
