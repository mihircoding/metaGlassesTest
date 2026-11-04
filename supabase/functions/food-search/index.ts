import { handleFoodSearch } from "../_shared/search.ts";

Deno.serve((req) => handleFoodSearch(req, { fdcKey: Deno.env.get("FDC_API_KEY") ?? "", fetchFn: fetch }));
