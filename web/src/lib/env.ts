/** Build-time configuration, all sourced from `VITE_*` environment variables. */

const DEFAULT_API_BASE_URL = "http://127.0.0.1:8000/api/v1";

export const env = {
  apiBaseUrl: (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? DEFAULT_API_BASE_URL,
  commandCentreName:
    (import.meta.env.VITE_COMMAND_CENTRE_NAME as string | undefined) ?? "State EOC — Gandhinagar",
} as const;
