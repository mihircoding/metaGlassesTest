export type Nutrients = {
  kcal: number; protein_g: number; carbs_g: number; fat_g: number;
  sat_fat_g: number; sodium_mg: number; fiber_g: number; sugar_g: number;
};
export const ZERO: Nutrients = { kcal: 0, protein_g: 0, carbs_g: 0, fat_g: 0, sat_fat_g: 0, sodium_mg: 0, fiber_g: 0, sugar_g: 0 };
const KEYS = Object.keys(ZERO) as (keyof Nutrients)[];

export type FoodItem = {
  name: string; brand?: string; source: "usda" | "off"; source_ref: string;
  serving_desc: string; serving_grams?: number; per_serving: Nutrients;
};
export type FdcFood = {
  fdcId: number; description: string; dataType?: string; brandName?: string; brandOwner?: string;
  servingSize?: number; servingSizeUnit?: string; householdServingFullText?: string;
  foodNutrients: { nutrientId: number; value?: number }[];
};
export type OffProduct = {
  product_name?: string; brands?: string; serving_size?: string;
  serving_quantity?: number | string; nutriments?: Record<string, unknown>;
};

const r1 = (x: number) => Math.round(x * 10) / 10;
const num = (v: unknown) => {
  const n = typeof v === "string" && v.trim() !== "" ? Number(v) : v;
  return typeof n === "number" && Number.isFinite(n) ? n : 0;
};

export function scale(n: Nutrients, factor: number): Nutrients {
  const out = { ...ZERO };
  for (const k of KEYS) out[k] = r1(n[k] * factor);
  return out;
}

export function sum(list: Nutrients[]): Nutrients {
  const out = { ...ZERO };
  for (const n of list) for (const k of KEYS) out[k] += n[k];
  for (const k of KEYS) out[k] = r1(out[k]);
  return out;
}

export function fromFdc(list: { nutrientId: number; value?: number }[]): Nutrients {
  const v = (id: number) => num(list.find((x) => x.nutrientId === id)?.value);
  const kcal = v(1008) || v(2047) || v(2048) || v(1062) / 4.184;
  return {
    kcal: r1(kcal), protein_g: r1(v(1003)), carbs_g: r1(v(1005)), fat_g: r1(v(1004)),
    sat_fat_g: r1(v(1258)), sodium_mg: r1(v(1093)), fiber_g: r1(v(1079)), sugar_g: r1(v(2000)),
  };
}

export function fromOff(n: Record<string, unknown>): Nutrients {
  const v = (k: string) => num(n[k]);
  return {
    kcal: r1(v("energy-kcal_100g") || v("energy_100g") / 4.184),
    protein_g: r1(v("proteins_100g")), carbs_g: r1(v("carbohydrates_100g")), fat_g: r1(v("fat_100g")),
    sat_fat_g: r1(v("saturated-fat_100g")),
    sodium_mg: r1(v("sodium_100g") * 1000 || v("salt_100g") * 400),
    fiber_g: r1(v("fiber_100g")), sugar_g: r1(v("sugars_100g")),
  };
}

export function barcodeVariants(code: string): string[] {
  const d = code.replace(/\D/g, "");
  const out = [d];
  if (d.length === 12) out.push("0" + d);
  if (d.length === 13 && d.startsWith("0")) out.push(d.slice(1));
  return [...new Set(out)].filter(Boolean);
}

export function titleCase(s: string): string {
  return s.toLowerCase().replace(/(^|[^a-z0-9'])([a-z])/g, (_, p, c) => p + c.toUpperCase());
}

export function fdcFoodToItem(food: FdcFood): FoodItem {
  const per100 = fromFdc(food.foodNutrients);
  const unit = food.servingSizeUnit?.toLowerCase();
  const size = food.servingSize;
  const labeled = food.dataType === "Branded" && size && size > 0 && ["g", "grm", "ml", "mlt"].includes(unit ?? "");
  const item: FoodItem = {
    name: food.dataType === "Branded" ? titleCase(food.description) : food.description, source: "usda", source_ref: String(food.fdcId),
    serving_desc: "100 g", serving_grams: 100, per_serving: per100,
  };
  const brand = food.brandName ?? food.brandOwner;
  if (brand) item.brand = brand;
  if (labeled) {
    const hh = food.householdServingFullText;
    item.serving_desc = hh ? `${hh} (${size} g)` : `${size} g`;
    item.serving_grams = size;
    item.per_serving = scale(per100, size / 100);
  }
  return item;
}

export function offProductToItem(code: string, p: OffProduct): FoodItem | null {
  if (!p.product_name) return null;
  const per100 = fromOff(p.nutriments ?? {});
  const q = num(p.serving_quantity);
  const item: FoodItem = {
    name: p.product_name, source: "off", source_ref: String(code),
    serving_desc: "100 g", serving_grams: 100, per_serving: per100,
  };
  if (p.brands) item.brand = p.brands;
  if (q > 0) {
    item.serving_desc = p.serving_size ?? `${q} g`;
    item.serving_grams = q;
    item.per_serving = scale(per100, q / 100);
  }
  return item;
}
