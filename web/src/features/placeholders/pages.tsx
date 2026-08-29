import { PlaceholderPage } from "./PlaceholderPage";

export function IncidentsPage() {
  return (
    <PlaceholderPage
      title="Incidents"
      slice="3"
      summary="Declaring an incident, setting its command structure and scoping every downstream record to it."
      scope={[
        "Incident declaration, severity and lifecycle state",
        "Sector and sub-sector breakdown",
        "Assignment of an incident commander",
        "Scoping of victims, tasks and resources to an incident",
      ]}
    />
  );
}

export function RespondersPage() {
  return (
    <PlaceholderPage
      title="Responders"
      slice="3"
      summary="The roster of teams and volunteers checked in to an incident, with their assignments."
      scope={[
        "Team composition and check-in / check-out",
        "Skill and equipment attributes",
        "Task assignment and acknowledgement",
        "Last-known position and reporting interval",
      ]}
    />
  );
}

export function MapPage() {
  return (
    <PlaceholderPage
      title="Operational map"
      slice="3"
      summary="A Leaflet map over PostGIS geometry showing responders, victims, hazards and sectors."
      scope={[
        "Responder and victim positions",
        "Hazard zones and exclusion areas",
        "Offline tile caching on the field device",
        "Sector boundaries and search progress",
      ]}
    />
  );
}

export function ResourcesPage() {
  return (
    <PlaceholderPage
      title="Resources"
      slice="4"
      summary="Tracking of consumables, equipment and transport across the response."
      scope={[
        "Stock levels by staging area",
        "Requests, allocations and transfers",
        "Hospital bed and capability availability",
        "Chain-of-custody for controlled items",
      ]}
    />
  );
}

export function SettingsPage() {
  return (
    <PlaceholderPage
      title="Settings"
      slice="4"
      summary="Command-centre configuration: users, roles, retention and integrations."
      scope={[
        "User administration and role assignment",
        "Synchronisation policy and conflict-resolution defaults",
        "Audit log retention",
        "External agency integrations",
      ]}
    />
  );
}

export function NotFoundPage() {
  return (
    <div className="mx-auto max-w-md py-16 text-center">
      <p className="font-mono text-sm text-ink-500">404</p>
      <h1 className="mt-2 text-lg font-semibold text-ink-100">Route not found</h1>
      <p className="mt-2 text-sm text-ink-400">
        This address does not correspond to any module in the Slice 1 build.
      </p>
    </div>
  );
}
