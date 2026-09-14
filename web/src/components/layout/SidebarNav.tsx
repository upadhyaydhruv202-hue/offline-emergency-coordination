import {
  AlertTriangle,
  Boxes,
  ClipboardList,
  Hospital,
  LayoutDashboard,
  Map,
  Radio,
  RefreshCw,
  ScrollText,
  Settings,
  Siren,
  Tent,
  Users,
  UserSquare2,
  type LucideIcon,
} from "lucide-react";
import { NavLink } from "react-router-dom";
import type { UserRole } from "../../lib/api/auth";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  roles?: UserRole[];
}

interface NavSection {
  heading: string;
  items: NavItem[];
}

const SECTIONS: NavSection[] = [
  {
    heading: "Operations",
    items: [
      { to: "/dashboard", label: "Overview", icon: LayoutDashboard },
      { to: "/map", label: "Live Map", icon: Map },
      { to: "/incidents", label: "Incidents", icon: Siren },
      { to: "/victims", label: "Victims", icon: UserSquare2 },
      { to: "/responders", label: "Responders", icon: Users },
      { to: "/hazards", label: "Hazards", icon: AlertTriangle },
      { to: "/tasks", label: "Tasks", icon: ClipboardList },
      { to: "/sos", label: "SOS Alerts", icon: Radio },
    ],
  },
  {
    heading: "Logistics",
    items: [
      { to: "/hospitals", label: "Hospitals", icon: Hospital },
      { to: "/shelters", label: "Shelters", icon: Tent },
      { to: "/resources", label: "Resources", icon: Boxes },
    ],
  },
  {
    heading: "System",
    items: [
      {
        to: "/sync",
        label: "Synchronisation",
        icon: RefreshCw,
        roles: ["INCIDENT_COMMANDER", "ADMIN", "RESCUE_TEAM", "MEDICAL_TEAM"],
      },
      {
        to: "/audit",
        label: "Audit / Events",
        icon: ScrollText,
        roles: ["INCIDENT_COMMANDER", "ADMIN", "RESCUE_TEAM", "MEDICAL_TEAM"],
      },
      { to: "/settings", label: "Settings", icon: Settings, roles: ["INCIDENT_COMMANDER", "ADMIN"] },
    ],
  },
];

export function SidebarNav({ role }: { role: UserRole }) {
  return (
    <nav aria-label="Primary" className="flex-1 overflow-y-auto px-3 py-4">
      {SECTIONS.map((section) => {
        const items = section.items.filter((item) => !item.roles || item.roles.includes(role));
        if (items.length === 0) return null;
        return (
          <div key={section.heading} className="mb-5">
            <p className="label-caps px-2 pb-2">{section.heading}</p>
            <ul className="space-y-0.5">
              {items.map(({ to, label, icon: Icon }) => (
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
                  </NavLink>
                </li>
              ))}
            </ul>
          </div>
        );
      })}
    </nav>
  );
}
