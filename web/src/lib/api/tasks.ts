import { apiRequest } from "./client";

export const TASK_PRIORITIES = ["CRITICAL", "HIGH", "MEDIUM", "LOW"] as const;
export type TaskPriority = (typeof TASK_PRIORITIES)[number];

export const TASK_STATUSES = [
  "PENDING",
  "ACCEPTED",
  "IN_PROGRESS",
  "COMPLETED",
  "CANCELLED",
] as const;
export type TaskStatus = (typeof TASK_STATUSES)[number];

export const TASK_STATUS_LABELS: Record<TaskStatus, string> = {
  PENDING: "Pending",
  ACCEPTED: "Accepted",
  IN_PROGRESS: "In progress",
  COMPLETED: "Completed",
  CANCELLED: "Cancelled",
};

export interface FieldTask {
  id: string;
  task_code: string;
  incident_id: string | null;
  assigned_to: string | null;
  title: string;
  description: string | null;
  priority: TaskPriority;
  status: TaskStatus;
  location: string | null;
  rank: number;
  created_at: string;
  updated_at: string;
}

export interface TaskBoard {
  total: number;
  open_tasks: number;
  by_status: {
    pending: number;
    accepted: number;
    in_progress: number;
    completed: number;
    cancelled: number;
  };
}

export interface TaskPage {
  items: FieldTask[];
  total: number;
}

export interface TaskQuery {
  search?: string;
  priority?: TaskPriority | null;
  status?: TaskStatus | null;
}

export function fetchTasks(
  token: string,
  query: TaskQuery = {},
  signal?: AbortSignal,
): Promise<TaskPage> {
  const params = new URLSearchParams();
  if (query.search?.trim()) params.set("search", query.search.trim());
  if (query.priority) params.set("priority", query.priority);
  if (query.status) params.set("status", query.status);
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<TaskPage>(`/tasks${suffix}`, { token, signal });
}

export function fetchTaskBoard(token: string, signal?: AbortSignal): Promise<TaskBoard> {
  return apiRequest<TaskBoard>("/tasks/board", { token, signal });
}
