import type { FdcFood, OffProduct } from "./nutrients.ts";

export type FetchFn = typeof fetch;

export async function searchFdc(
  query: string, dataTypes: string[], apiKey: string, fetchFn: FetchFn, pageSize = 25,
): Promise<FdcFood[]> {
  const res = await fetchFn(`https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(apiKey)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query, dataType: dataTypes, pageSize }),
  });
  if (!res.ok) throw new Error(`fdc ${res.status}`);
  const body = await res.json();
  return (body.foods ?? []) as FdcFood[];
}

export async function fetchOffProduct(code: string, fetchFn: FetchFn): Promise<OffProduct | null> {
  const res = await fetchFn(
    `https://world.openfoodfacts.org/api/v2/product/${code}.json?fields=product_name,brands,serving_size,serving_quantity,nutriments`,
    { headers: { "User-Agent": "NutraVision/1.0 (demo app)" } },
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`off ${res.status}`);
  const body = await res.json();
  return body.status === 1 ? (body.product as OffProduct) : null;
}
