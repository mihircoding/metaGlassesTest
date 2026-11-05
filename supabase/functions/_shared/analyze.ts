import { fromFdc, scale, sum, ZERO } from "./nutrients.ts";
import type { Nutrients } from "./nutrients.ts";
import { searchFdc } from "./fdc.ts";
import type { FetchFn } from "./fdc.ts";
import type { ClaudeFood } from "./claude.ts";

export type CallClaude = (imageB64: string, mediaType: string) => Promise<ClaudeFood>;
export type AnalyzedItem = {
  name: string; grams: number; confidence: "high" | "medium" | "low";
  source: "usda" | "ai_estimate"; source_ref?: string; nutrients: Nutrients;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

export async function handleAnalyzeFood(
  req: Request, deps: { fdcKey: string; fetchFn: FetchFn; callClaude: CallClaude },
): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  let body: { image_base64?: unknown; media_type?: unknown };
  try { body = await req.json() ?? {}; } catch { body = {}; }
  const img = body.image_base64;
  const mt = body.media_type;
  if (typeof img !== "string" || img.length === 0 || img.length > 1_500_000 || (mt !== "image/jpeg" && mt !== "image/png")) {
    return json({ error: "Send image_base64 (jpeg/png, under 1.5 MB) and media_type" }, 400);
  }

  let food: ClaudeFood;
  try { food = await deps.callClaude(img, mt); } catch { return json({ error: "AI analysis failed" }, 502); }
  if (!food.is_food) return json({ is_food: false, items: [], totals: ZERO, notes: food.notes });

  const items: AnalyzedItem[] = await Promise.all(food.items.map(async (it): Promise<AnalyzedItem> => {
    try {
      const [hit] = await searchFdc(it.fdc_query, ["Survey (FNDDS)", "Foundation", "SR Legacy"], deps.fdcKey, deps.fetchFn, 5);
      if (hit) {
        return {
          name: it.name, grams: it.grams, confidence: it.confidence, source: "usda",
          source_ref: String(hit.fdcId), nutrients: scale(fromFdc(hit.foodNutrients), it.grams / 100),
        };
      }
    } catch { /* fall through to the AI estimate */ }
    return { name: it.name, grams: it.grams, confidence: it.confidence, source: "ai_estimate", nutrients: it.estimate };
  }));
  return json({ is_food: true, items, totals: sum(items.map((i) => i.nutrients)), notes: food.notes });
}
