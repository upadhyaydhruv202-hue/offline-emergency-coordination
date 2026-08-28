import { createBrowserRouter, RouterProvider } from "react-router-dom";
import { AuthProvider } from "../features/auth/AuthProvider";
import { routes } from "./routes";

const router = createBrowserRouter(routes);

export function App() {
  return (
    <AuthProvider>
      <RouterProvider router={router} />
    </AuthProvider>
  );
}
