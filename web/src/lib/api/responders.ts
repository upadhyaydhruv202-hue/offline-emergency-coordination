import { apiRequest } from "./client";
import type { AuthenticatedUser, UserRole } from "./auth";

export type Responder = AuthenticatedUser;

export interface ResponderPage {
  items: Responder[];
  total: number;
}

export interface ResponderQuery {
  search?: string;
  role?: UserRole | null;
  is_active?: boolean | null;
}

export function fetchResponders(
  token: string,
  query: ResponderQuery = {},
  signal?: AbortSignal,
): Promise<ResponderPage> {
  const params = new URLSearchParams();
  if (query.search?.trim()) params.set("search", query.search.trim());
  if (query.role) params.set("role", query.role);
  if (query.is_active === true) params.set("is_active", "true");
  if (query.is_active === false) params.set("is_active", "false");
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<ResponderPage>(`/responders${suffix}`, { token, signal });
}
