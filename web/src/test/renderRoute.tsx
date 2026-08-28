import { render, type RenderResult } from "@testing-library/react";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { routes } from "../app/routes";
import { AuthProvider } from "../features/auth/AuthProvider";

/** Mounts the real route table in memory, wrapped in the real auth provider. */
export function renderRoute(initialPath = "/"): RenderResult {
  const router = createMemoryRouter(routes, { initialEntries: [initialPath] });
  return render(
    <AuthProvider>
      <RouterProvider router={router} />
    </AuthProvider>,
  );
}
