import { test } from "node:test";
import assert from "node:assert/strict";
import { parseClaudeFood, type ClaudeFood } from "../_shared/claude.ts";
import { handleAnalyzeFood } from "../_shared/analyze.ts";
import { fakeFetch } from "./helpers.ts";

const est = { kcal: 200, protein_g: 4, carbs_g: 44, fat_g: 0.4, sat_fat_g: 0.1, sodium_mg: 2, fiber_g: 0.6, sugar_g: 0 };

test("parseClaudeFood clamps and drops", () => {
  const base = { name: "Rice", fdc_query: "Rice, white, cooked", cooking_method: "boiled", confidence: "high",
    estimate: { kcal: 200, protein_g: 4, carbs_g: 44, fat_g: 0.4, sat_fat_g: 0.1, sodium_mg: 2, fiber_g: 0.6, sugar_g: 0 } };
  const r = parseClaudeFood(JSON.stringify({ is_food: true, notes: "", package: null, items: [
    { ...base, grams: 0 }, { ...base, grams: -5 }, { ...base, grams: 5000 }, { ...base, name: "  ", grams: 100 }] }));
  assert.deepEqual(r.items.map(i => i.grams), [1, 1, 2000]);
  assert.equal(parseClaudeFood(JSON.stringify({ is_food: true, notes: "", package: null, items: [] })).is_food, false);
  assert.throws(() => parseClaudeFood("not json"));
});

const item = (name: string, grams: number) => ({
  name, fdc_query: name, grams, cooking_method: "none", confidence: "high" as const, estimate: est,
});
const food = (items: ReturnType<typeof item>[]): ClaudeFood =>
  ({ is_food: true, notes: "ok", package: null, items });
const fdcHit = { foods: [{ fdcId: 123, description: "Chicken", foodNutrients: [{ nutrientId: 1008, value: 165 }] }] };

const call = (claude: () => Promise<ClaudeFood>, routes: Parameters<typeof fakeFetch>[0], init?: RequestInit) =>
  handleAnalyzeFood(
    new Request("http://x/analyze-food", init ?? { method: "POST", body: JSON.stringify({ image_base64: "AAAA", media_type: "image/jpeg" }) }),
    { fdcKey: "k", fetchFn: fakeFetch(routes), callClaude: claude },
  );

test("usda match scales per 100 g", async () => {
  const res = await call(async () => food([item("Chicken", 150)]), [{ match: "api.nal.usda.gov", body: fdcHit }]);
  assert.equal(res.status, 200);
  const j = await res.json();
  assert.equal(j.items[0].source, "usda");
  assert.equal(j.items[0].source_ref, "123");
  assert.equal(j.items[0].nutrients.kcal, 247.5);
  assert.equal(j.totals.kcal, 247.5);
});

test("no FDC match falls back to estimate", async () => {
  let n = 0;
  const fetchRoutes = [{ match: "api.nal.usda.gov", get body() { return n++ === 0 ? fdcHit : { foods: [] }; } }];
  const res = await call(async () => food([item("Chicken", 150), item("Mystery", 100)]), fetchRoutes);
  const j = await res.json();
  assert.equal(j.items[1].source, "ai_estimate");
  assert.equal(j.items[1].source_ref, undefined);
  assert.deepEqual(j.items[1].nutrients, est);
  assert.equal(j.totals.kcal, 447.5);
});

test("FDC errors fall back to estimates", async () => {
  const res = await call(async () => food([item("A", 100), item("B", 100)]), [{ match: "api.nal.usda.gov", body: {}, status: 500 }]);
  assert.equal(res.status, 200);
  assert.deepEqual((await res.json()).items.map((i: { source: string }) => i.source), ["ai_estimate", "ai_estimate"]);
});

test("not food", async () => {
  const res = await call(async () => ({ is_food: false, notes: "desk", package: null, items: [] }), []);
  const j = await res.json();
  assert.equal(j.is_food, false);
  assert.deepEqual(j.items, []);
  assert.equal(j.totals.kcal, 0);
});

test("errors: claude failure, bad input, wrong method", async () => {
  const ok = async () => food([]);
  const res = await call(async () => { throw new Error("boom"); }, []);
  assert.equal(res.status, 502);
  assert.deepEqual(await res.json(), { error: "AI analysis failed" });
  const post = (b: unknown) => ({ method: "POST", body: JSON.stringify(b) });
  assert.equal((await call(ok, [], post({ media_type: "image/jpeg" }))).status, 400);
  assert.equal((await call(ok, [], post({ image_base64: "AAAA", media_type: "image/gif" }))).status, 400);
  assert.equal((await call(ok, [], { method: "POST", body: "nope" })).status, 400);
  assert.equal((await call(ok, [], { method: "GET" })).status, 405);
});
