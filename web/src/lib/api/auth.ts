import { apiRequest } from "./client";

export const USER_ROLES = [
  "RESCUE_TEAM",
  "MEDICAL_TEAM",
  "VOLUNTEER",
  "INCIDENT_COMMANDER",
  "ADMIN",
] as const;

export type UserRole = (typeof USER_ROLES)[number];

export const ROLE_LABELS: Record<UserRole, string> = {
  RESCUE_TEAM: "Rescue Team",
  MEDICAL_TEAM: "Medical Team",
  VOLUNTEER: "Volunteer",
  INCIDENT_COMMANDER: "Incident Commander",
  ADMIN: "Administrator",
};

export interface AuthenticatedUser {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
  is_active: boolean;
  created_at: string;
}

export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  user: AuthenticatedUser;
}

export function login(email: string, password: string): Promise<LoginResponse> {
  return apiRequest<LoginResponse>("/auth/login", {
    method: "POST",
    body: { email, password },
  });
}

export function fetchCurrentUser(token: string): Promise<AuthenticatedUser> {
  return apiRequest<AuthenticatedUser>("/auth/me", { token });
}
