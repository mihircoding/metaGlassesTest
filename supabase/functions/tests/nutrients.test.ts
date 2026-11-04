import { test } from "node:test";
import assert from "node:assert/strict";
import { fromFdc, fromOff, scale, sum, barcodeVariants, titleCase, fdcFoodToItem, offProductToItem } from "../_shared/nutrients.ts";

test("fromFdc energy fallbacks and missing fields", () => {
  assert.deepEqual(fromFdc([{ nutrientId: 1008, value: 52 }, { nutrientId: 1003, value: 0.3 }, { nutrientId: 1093, value: 1 }]),
    { kcal: 52, protein_g: 0.3, carbs_g: 0, fat_g: 0, sat_fat_g: 0, sodium_mg: 1, fiber_g: 0, sugar_g: 0 });
  assert.equal(fromFdc([{ nutrientId: 2047, value: 100 }]).kcal, 100);
  assert.equal(fromFdc([{ nutrientId: 1062, value: 418.4 }]).kcal, 100);
  assert.equal(fromFdc([{ nutrientId: 1008 }]).kcal, 0);
});
test("fromOff salt, kJ and strings", () => {
  assert.equal(fromOff({ sodium_100g: 0.4 }).sodium_mg, 400);
  assert.equal(fromOff({ salt_100g: 1 }).sodium_mg, 400);
  assert.equal(fromOff({ energy_100g: 1000 }).kcal, 239);
  assert.equal(fromOff({ "energy-kcal_100g": "120", "saturated-fat_100g": "2.5" }).sat_fat_g, 2.5);
});
test("scale and sum round to one decimal", () => {
  assert.equal(scale({ ...fromFdc([{ nutrientId: 1008, value: 165 }]) }, 1.5).kcal, 247.5);
  assert.equal(sum([scale(fromFdc([{ nutrientId: 1003, value: 1 }]), 0.33), scale(fromFdc([{ nutrientId: 1003, value: 1 }]), 0.33)]).protein_g, 0.6);
});
test("barcode variants", () => {
  assert.deepEqual(barcodeVariants("012345678905"), ["012345678905", "0012345678905"]);
  assert.deepEqual(barcodeVariants("0012345678905"), ["0012345678905", "012345678905"]);
  assert.deepEqual(barcodeVariants(" 4006381333931 "), ["4006381333931"]);
});
test("titleCase", () => assert.equal(titleCase("GREEK YOGURT, PLAIN"), "Greek Yogurt, Plain"));
test("branded FDC food uses labeled serving", () => {
  const item = fdcFoodToItem({ fdcId: 2035482, description: "GREEK YOGURT", dataType: "Branded", brandName: "OCEAN SPRAY",
    servingSize: 30, servingSizeUnit: "g", householdServingFullText: "2 Tbsp",
    foodNutrients: [{ nutrientId: 1008, value: 400 }, { nutrientId: 1003, value: 3.33 }] });
  assert.deepEqual([item.name, item.brand, item.source, item.source_ref, item.serving_desc, item.serving_grams, item.per_serving.kcal],
    ["Greek Yogurt", "OCEAN SPRAY", "usda", "2035482", "2 Tbsp (30 g)", 30, 120]);
});
test("generic FDC food is per 100 g", () => {
  const item = fdcFoodToItem({ fdcId: 1, description: "Apples, raw", dataType: "Foundation", foodNutrients: [{ nutrientId: 2047, value: 52 }] });
  assert.deepEqual([item.name, item.serving_desc, item.serving_grams, item.per_serving.kcal], ["Apples, raw", "100 g", 100, 52]);
});
test("OFF product", () => {
  assert.equal(offProductToItem("1", { nutriments: {} }), null);
  const item = offProductToItem("3017620422003", { product_name: "Nutella", brands: "Ferrero", serving_size: "15 g", serving_quantity: "15",
    nutriments: { "energy-kcal_100g": 540, sodium_100g: 0.04 } })!;
  assert.deepEqual([item.source, item.serving_desc, item.serving_grams, item.per_serving.kcal, item.per_serving.sodium_mg],
    ["off", "15 g", 15, 81, 6]);
});
test("recorded fixtures map without NaN", async () => {
  const { readFile } = await import("node:fs/promises");
  for (const f of ["fdc_search_text.json", "fdc_search_barcode.json"]) {
    const foods = JSON.parse(await readFile(new URL(`./fixtures/${f}`, import.meta.url), "utf8")).foods;
    for (const item of foods.map(fdcFoodToItem)) for (const v of Object.values(item.per_serving)) assert.ok(Number.isFinite(v));
  }
});
