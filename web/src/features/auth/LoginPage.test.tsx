import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { renderRoute } from "../../test/renderRoute";
import { stubLoginFailure, stubSignedInApi, stubUnreachableApi } from "../../test/stubApi";

async function submitCredentials(password = "Rescue-Demo-2026") {
  const user = userEvent.setup();
  await user.type(await screen.findByLabelText(/email/i), "commander@drp.example");
  await user.type(screen.getByLabelText(/password/i), password);
  await user.click(screen.getByRole("button", { name: /sign in/i }));
}

describe("sign-in", () => {
  it("authenticates and reaches the dashboard", async () => {
    stubSignedInApi();
    renderRoute("/login");

    await submitCredentials();

    expect(
      await screen.findByRole("heading", { name: /operational overview/i }),
    ).toBeInTheDocument();
    expect(localStorage.getItem("drp.accessToken")).toBe("test.access.token");
  });

  it("reports rejected credentials without leaking which field was wrong", async () => {
    stubLoginFailure(401, "authentication_failed", "Invalid email or password");
    renderRoute("/login");

    await submitCredentials("Wrong-Password-1");

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent(/invalid email or password/i);
    expect(localStorage.getItem("drp.accessToken")).toBeNull();
  });

  it("reports an unreachable backend distinctly from a rejected password", async () => {
    stubUnreachableApi();
    renderRoute("/login");

    await submitCredentials();

    expect(await screen.findByRole("alert")).toHaveTextContent(/cannot reach the coordination backend/i);
  });
});
