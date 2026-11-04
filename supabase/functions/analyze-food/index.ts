import Anthropic from "npm:@anthropic-ai/sdk@0.137.0";
import { MODEL, OUTPUT_SCHEMA, SYSTEM_PROMPT, parseClaudeFood } from "../_shared/claude.ts";
import { handleAnalyzeFood, type CallClaude } from "../_shared/analyze.ts";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
const callClaude: CallClaude = async (data, mediaType) => {
  const res = await client.beta.messages.create({
    model: MODEL, max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"], fallbacks: "default",
    output_config: { effort: "low", format: { type: "json_schema", schema: OUTPUT_SCHEMA } },
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: [
      { type: "image", source: { type: "base64", media_type: mediaType, data } },
      { type: "text", text: "Identify the food in this photo." },
    ] }],
  });
  if (res.stop_reason === "refusal") throw new Error("refused");
  const text = res.content.find((b) => b.type === "text");
  return parseClaudeFood(text && "text" in text ? text.text : "");
};
Deno.serve((req) => handleAnalyzeFood(req, { fdcKey: Deno.env.get("FDC_API_KEY") ?? "", fetchFn: fetch, callClaude }));
