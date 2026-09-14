import { Navigate, type RouteObject } from "react-router-dom";
import { CommandShell } from "../components/layout/CommandShell";
import { LoginPage } from "../features/auth/LoginPage";
import { DashboardPage } from "../features/dashboard/DashboardPage";
import { HazardsPage } from "../features/hazards/HazardsPage";
import { IncidentsPage } from "../features/incidents/IncidentsPage";
import {
  MapPage,
  NotFoundPage,
  ResourcesPage,
  SettingsPage,
} from "../features/placeholders/pages";
import { RespondersPage } from "../features/responders/RespondersPage";
import { SosPage } from "../features/sos/SosPage";
import { ConflictViewerPage } from "../features/sync/ConflictViewerPage";
import { SyncDashboardPage } from "../features/sync/SyncDashboardPage";
import { TasksPage } from "../features/tasks/TasksPage";
import { VictimsPage } from "../features/victims/VictimsPage";
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
          { path: "hazards", element: <HazardsPage /> },
          { path: "sos", element: <SosPage /> },
          { path: "tasks", element: <TasksPage /> },
          { path: "sync", element: <SyncDashboardPage /> },
          { path: "sync/conflicts", element: <ConflictViewerPage /> },
          { path: "map", element: <MapPage /> },
          { path: "resources", element: <ResourcesPage /> },
          { path: "settings", element: <SettingsPage /> },
          { path: "*", element: <NotFoundPage /> },
        ],
      },
    ],
  },
];
