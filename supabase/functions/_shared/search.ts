import { barcodeVariants, fdcFoodToItem, offProductToItem } from "./nutrients.ts";
import type { FdcFood, FoodItem } from "./nutrients.ts";
import { fetchOffProduct, searchFdc } from "./fdc.ts";
import type { FetchFn } from "./fdc.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

export async function handleFoodSearch(
  req: Request, deps: { fdcKey: string; fetchFn: FetchFn },
): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  let body: { query?: unknown; barcode?: unknown };
  try { body = await req.json() ?? {}; } catch { body = {}; }
  const query = typeof body.query === "string" ? body.query.trim() : "";
  const barcode = typeof body.barcode === "string" ? body.barcode : "";
  const variants = barcodeVariants(barcode);
  if (query.length < 2 && variants.length === 0) return json({ error: "Send a query or a barcode" }, 400);

  const { fdcKey, fetchFn } = deps;
  try {
    let items: FoodItem[] = [];
    if (query.length >= 2) {
      const foods = await searchFdc(query, ["Foundation", "SR Legacy", "Survey (FNDDS)", "Branded"], fdcKey, fetchFn);
      items = foods.map(fdcFoodToItem);
    } else {
      for (const v of variants) {
        const foods = await searchFdc(v, ["Branded"], fdcKey, fetchFn, 10) as (FdcFood & { gtinUpc?: string })[];
        const hit = foods.find((f) => f.gtinUpc && variants.includes(f.gtinUpc));
        if (hit) { items = [fdcFoodToItem(hit)]; break; }
      }
      for (const v of items.length ? [] : variants) {
        const p = await fetchOffProduct(v, fetchFn);
        const item = p && offProductToItem(v, p);
        if (item) { items = [item]; break; }
      }
    }
    return json({ items });
  } catch {
    return json({ error: "Food database unavailable" }, 502);
  }
}
