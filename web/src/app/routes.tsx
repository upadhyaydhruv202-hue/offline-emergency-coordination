import { Navigate, type RouteObject } from "react-router-dom";
import { CommandShell } from "../components/layout/CommandShell";
import { LoginPage } from "../features/auth/LoginPage";
import { DashboardPage } from "../features/dashboard/DashboardPage";
import {
  IncidentsPage,
  MapPage,
  NotFoundPage,
  ResourcesPage,
  RespondersPage,
  SettingsPage,
  VictimsPage,
} from "../features/placeholders/pages";
import { ProtectedRoute } from "./ProtectedRoute";

/** Exported separately from the router so tests can mount them in memory. */
export const routes: RouteObject[] = [
  { path: "/login", element: <LoginPage /> },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <CommandShell />,
        children: [
          { index: true, element: <Navigate to="/dashboard" replace /> },
          { path: "dashboard", element: <DashboardPage /> },
          { path: "incidents", element: <IncidentsPage /> },
          { path: "responders", element: <RespondersPage /> },
          { path: "victims", element: <VictimsPage /> },
          { path: "map", element: <MapPage /> },
          { path: "resources", element: <ResourcesPage /> },
          { path: "settings", element: <SettingsPage /> },
          { path: "*", element: <NotFoundPage /> },
        ],
      },
    ],
  },
];
