import type { Nutrients } from "./nutrients.ts";

export const MODEL = "claude-opus-5-5";

export const SYSTEM_PROMPT = `You are a nutrition analyst. You receive one photo of a meal, snack, drink or food package and identify the food in it.

Rules:
- List each distinct food separately (for example rice, chicken and salad are three items), never one combined dish line.
- Estimate the grams of the visible portion of each item. Use the plate (a dinner plate is about 27 cm), utensils and hands for scale.
- Write fdc_query in USDA FoodData Central naming style, for example "Chicken, breast, roasted" or "Rice, white, cooked".
- Give estimate: your own nutrient numbers for the estimated grams of that item (the whole portion, not per 100 g), used only if the USDA lookup fails.
- If packaging is visible, read the brand and product name into package; otherwise set package to null.
- Set is_food to false and items to [] when no food is visible.
- Keep notes to one sentence.`;

const NUTRIENT_KEYS = ["kcal", "protein_g", "carbs_g", "fat_g", "sat_fat_g", "sodium_mg", "fiber_g", "sugar_g"] as const;
const str = { type: "string" };

export const OUTPUT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["is_food", "notes", "package", "items"],
  properties: {
    is_food: { type: "boolean" },
    notes: str,
    package: {
      anyOf: [
        { type: "null" },
        { type: "object", additionalProperties: false, required: ["brand", "product"], properties: { brand: str, product: str } },
      ],
    },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "fdc_query", "grams", "cooking_method", "confidence", "estimate"],
        properties: {
          name: str, fdc_query: str, grams: { type: "number" }, cooking_method: str,
          confidence: { type: "string", enum: ["high", "medium", "low"] },
          estimate: {
            type: "object",
            additionalProperties: false,
            required: [...NUTRIENT_KEYS],
            properties: Object.fromEntries(NUTRIENT_KEYS.map((k) => [k, { type: "number" }])),
          },
        },
      },
    },
  },
};

export type ClaudeItem = {
  name: string; fdc_query: string; grams: number; cooking_method: string;
  confidence: "high" | "medium" | "low"; estimate: Nutrients;
};
export type ClaudeFood = {
  is_food: boolean; notes: string; package: { brand: string; product: string } | null; items: ClaudeItem[];
};

const isNum = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

export function parseClaudeFood(text: string): ClaudeFood {
  const raw = JSON.parse(text);
  if (!raw || typeof raw !== "object" || typeof raw.is_food !== "boolean" || !Array.isArray(raw.items)) {
    throw new Error("bad claude shape");
  }
  const items: ClaudeItem[] = [];
  for (const it of raw.items) {
    if (!it || typeof it.name !== "string" || typeof it.fdc_query !== "string" || !isNum(it.grams) || !it.estimate) {
      throw new Error("bad claude item");
    }
    const name = it.name.trim();
    if (!name) continue;
    const estimate = {} as Nutrients;
    for (const k of NUTRIENT_KEYS) {
      if (!isNum(it.estimate[k])) throw new Error("bad claude estimate");
      estimate[k] = it.estimate[k];
    }
    items.push({
      name, fdc_query: it.fdc_query, grams: Math.min(2000, Math.max(1, it.grams)),
      cooking_method: typeof it.cooking_method === "string" ? it.cooking_method : "",
      confidence: ["high", "medium", "low"].includes(it.confidence) ? it.confidence : "low",
      estimate,
    });
  }
  const pkg = raw.package && typeof raw.package.brand === "string" && typeof raw.package.product === "string"
    ? { brand: raw.package.brand, product: raw.package.product } : null;
  return { is_food: raw.is_food && items.length > 0, notes: typeof raw.notes === "string" ? raw.notes : "", package: pkg, items };
}
