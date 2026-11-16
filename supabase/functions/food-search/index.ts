import { handleFoodSearch } from "../_shared/search.ts";

Deno.serve((req) => handleFoodSearch(req, { fdcKey: Deno.env.get("FDC_API_KEY") || "DEMO_KEY", fetchFn: fetch }));
