import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { handleFoodSearch } from "../_shared/search.ts";

const fx = (name: string) => JSON.parse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8"));
const textFx = fx("fdc_search_text.json");
const barcodeFx = fx("fdc_search_barcode.json");
const offFx = fx("off_product.json");

// Routes match by URL substring; first match wins.
function fakeFetch(routes: { match: string; body: unknown; status?: number }[]): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = String(input);
    const r = routes.find((x) => url.includes(x.match));
    if (!r) throw new Error(`unrouted ${url}`);
    return new Response(JSON.stringify(r.body), { status: r.status ?? 200 });
  }) as typeof fetch;
}

const call = (init: RequestInit, routes: Parameters<typeof fakeFetch>[0]) =>
  handleFoodSearch(new Request("http://x/food-search", init), { fdcKey: "k", fetchFn: fakeFetch(routes) });
const post = (body: unknown) => ({ method: "POST", body: JSON.stringify(body) });

test("text query returns FDC items", async () => {
  const res = await call(post({ query: "greek yogurt" }), [{ match: "api.nal.usda.gov", body: textFx }]);
  assert.equal(res.status, 200);
  const { items } = await res.json();
  assert.equal(items.length, textFx.foods.length);
  assert.equal(items[0].source, "usda");
});

test("barcode matches FDC via EAN-13 variant", async () => {
  const res = await call(post({ barcode: "0031200037206" }), [{ match: "api.nal.usda.gov", body: barcodeFx }]);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).items.length, 1);
});

test("barcode falls back to Open Food Facts", async () => {
  const res = await call(post({ barcode: "3017620422003" }), [
    { match: "api.nal.usda.gov", body: { foods: [] } },
    { match: "openfoodfacts", body: offFx },
  ]);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).items[0].source, "off");
});

test("barcode found nowhere returns empty items", async () => {
  const res = await call(post({ barcode: "3017620422003" }), [
    { match: "api.nal.usda.gov", body: { foods: [] } },
    { match: "openfoodfacts", body: { status: 0 } },
  ]);
  assert.equal(res.status, 200);
  assert.deepEqual((await res.json()).items, []);
});

test("bad input, wrong method and upstream failure", async () => {
  assert.equal((await call(post({}), [])).status, 400);
  assert.equal((await call(post({ query: "a" }), [])).status, 400);
  assert.equal((await call({ method: "POST", body: "nope" }, [])).status, 400);
  assert.equal((await call({ method: "GET" }, [])).status, 405);
  const res = await call(post({ query: "rice" }), [{ match: "api.nal.usda.gov", body: {}, status: 500 }]);
  assert.equal(res.status, 502);
  assert.deepEqual(await res.json(), { error: "Food database unavailable" });
});
