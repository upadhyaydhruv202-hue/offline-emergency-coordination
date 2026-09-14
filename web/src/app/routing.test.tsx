import { screen, waitFor } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { renderRoute } from "../test/renderRoute";

describe("application startup", () => {
  it("mounts without crashing and lands on the sign-in screen", async () => {
    renderRoute("/");

    expect(
      await screen.findByRole("heading", { name: /command centre sign-in/i }),
    ).toBeInTheDocument();
  });

  it("renders the sign-in form controls", async () => {
    renderRoute("/login");

    expect(await screen.findByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /sign in/i })).toBeInTheDocument();
  });
});

describe("routing", () => {
  it.each([
    ["/dashboard"],
    ["/incidents"],
    ["/responders"],
    ["/victims"],
    ["/hazards"],
    ["/sos"],
    ["/tasks"],
    ["/map"],
    ["/resources"],
    ["/settings"],
  ])("redirects %s to /login while unauthenticated", async (path) => {
    renderRoute(path);

    await waitFor(() =>
      expect(screen.getByRole("heading", { name: /command centre sign-in/i })).toBeInTheDocument(),
    );
  });

  it("does not leak protected content to anonymous visitors", async () => {
    renderRoute("/dashboard");

    await screen.findByRole("heading", { name: /command centre sign-in/i });
    expect(screen.queryByText(/operational overview/i)).not.toBeInTheDocument();
  });
});
