declare global {
  interface Window {
    __BUGTRACKER_API_URL__?: string;
  }
}

/** Browser: Helm-mounted /runtime-config.js. Node/Jest: NEXT_PUBLIC_API_URL. */
export function getApiBaseUrl(): string {
  if (typeof window !== "undefined" && window.__BUGTRACKER_API_URL__) {
    return window.__BUGTRACKER_API_URL__.replace(/\/$/, "");
  }
  return (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080").replace(
    /\/$/,
    ""
  );
}

export const API_BASE_URL = getApiBaseUrl();
