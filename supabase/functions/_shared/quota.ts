import type { FetchFn } from "./fdc.ts";

export type ScanQuota = "ok" | "unauthorized" | "limit";
export type ClaimScan = (req: Request) => Promise<ScanQuota>;

/** Counts one AI scan against the caller's daily allowance (`claim_ai_scan()`, migration 0005), as the caller. */
export function claimScanVia(supabaseUrl: string, anonKey: string, fetchFn: FetchFn): ClaimScan {
  return async (req) => {
    const res = await fetchFn(`${supabaseUrl}/rest/v1/rpc/claim_ai_scan`, {
      method: "POST",
      headers: { apikey: anonKey, Authorization: req.headers.get("Authorization") ?? "", "Content-Type": "application/json" },
      body: "{}",
    });
    if (res.status === 429) return "limit";
    if (res.status === 401 || res.status === 403) return "unauthorized";
    // Anything else (the migration not applied yet, a database hiccup) shouldn't take scanning down.
    if (!res.ok) console.error("claim_ai_scan failed", res.status, await res.text());
    return "ok";
  };
}
