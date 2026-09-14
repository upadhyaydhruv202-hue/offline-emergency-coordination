import {
  AlertTriangle,
  Boxes,
  ClipboardList,
  LayoutDashboard,
  Map,
  Radio,
  RefreshCw,
  Settings,
  Siren,
  Users,
  UserSquare2,
  type LucideIcon,
} from "lucide-react";
import { NavLink } from "react-router-dom";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  /** Slice that makes this page functional; undefined means it works today. */
  slice?: string;
}

interface NavSection {
  heading: string;
  items: NavItem[];
}

const SECTIONS: NavSection[] = [
  {
    heading: "Operations",
    items: [
      { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
      { to: "/incidents", label: "Incidents", icon: Siren },
      { to: "/responders", label: "Responders", icon: Users },
      { to: "/victims", label: "Victims", icon: UserSquare2 },
      { to: "/hazards", label: "Hazards", icon: AlertTriangle },
      { to: "/sos", label: "SOS", icon: Radio },
      { to: "/tasks", label: "Tasks", icon: ClipboardList },
      { to: "/sync", label: "Synchronisation", icon: RefreshCw },
      { to: "/map", label: "Map", icon: Map, slice: "S5" },
    ],
  },
  {
    heading: "Logistics",
    items: [{ to: "/resources", label: "Resources", icon: Boxes, slice: "S4" }],
  },
  {
    heading: "System",
    items: [{ to: "/settings", label: "Settings", icon: Settings, slice: "S4" }],
  },
];

export function SidebarNav() {
  return (
    <nav aria-label="Primary" className="flex-1 overflow-y-auto px-3 py-4">
      {SECTIONS.map((section) => (
        <div key={section.heading} className="mb-5">
          <p className="label-caps px-2 pb-2">{section.heading}</p>
          <ul className="space-y-0.5">
            {section.items.map(({ to, label, icon: Icon, slice }) => (
              <li key={to}>
                <NavLink
                  to={to}
                  className={({ isActive }) =>
                    [
                      "group flex items-center gap-2.5 rounded-sm px-2 py-1.5 text-sm transition-colors",
                      isActive
                        ? "bg-accent-500/12 text-ink-100 shadow-[inset_2px_0_0_0_var(--color-accent-500)]"
                        : "text-ink-400 hover:bg-navy-800 hover:text-ink-200",
                    ].join(" ")
                  }
                >
                  <Icon className="size-4 shrink-0" aria-hidden />
                  <span className="flex-1 truncate">{label}</span>
                  {slice && (
                    <span
                      className="rounded-xs border border-navy-600 px-1 text-[10px] font-semibold tracking-wide text-ink-500"
                      title={`Planned for slice ${slice.slice(1)}`}
                    >
                      {slice}
                    </span>
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </nav>
  );
}
