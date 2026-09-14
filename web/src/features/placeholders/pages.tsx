import { PlaceholderPage } from "./PlaceholderPage";

export function SettingsPage() {
  return (
    <PlaceholderPage
      title="Settings"
      slice="6"
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
        This address does not correspond to any module in this build.
      </p>
    </div>
  );
}
