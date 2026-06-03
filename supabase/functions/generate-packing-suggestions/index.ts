// Supabase Edge Function: generate-packing-suggestions
//
// Generates AI packing list items for a trip context using the Claude API.
//
// ─────────────────────────────────────────────────────────────────────────────
// NOTE FOR DEPLOYMENT
// This file is a faithful RECONSTRUCTION of the deployed function from its known
// request/response contract (the live source is not checked into this repo).
// Before `supabase functions deploy generate-packing-suggestions`, reconcile it
// against your deployed version. If you prefer to keep your existing function
// body, you only need to port the lines marked `// [weather-aware]` below:
//   1. the new `destinations` (structured) + `travel_months` request fields
//   2. the `seasonalContext()` helper
//   3. the seasonal-weather paragraph added to the prompt
// ─────────────────────────────────────────────────────────────────────────────

import Anthropic from "npm:@anthropic-ai/sdk";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Match the model used by the project's other Claude edge functions
// (generate-itinerary, parse-expense-text, etc.).
const MODEL = "claude-sonnet-4-6";

// Allowed categories — must mirror PackingCategory in
// lib/models/packing_item.dart.
const CATEGORIES = [
  "clothing",
  "toiletries",
  "electronics",
  "documents",
  "health",
  "gear",
  "other",
];

interface DestinationContext {
  name: string;
  city?: string;
  province?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
}

function destinationLabel(d: DestinationContext): string {
  const parts = [d.name, d.city, d.province, d.country].filter(
    (p) => p && p.trim().length > 0,
  );
  // De-dupe while preserving order (name often equals city).
  const seen = new Set<string>();
  const unique = parts.filter((p) => {
    const key = p!.toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  const label = unique.join(", ");
  if (d.latitude != null && d.longitude != null) {
    return `${label} (${d.latitude.toFixed(2)}, ${d.longitude.toFixed(2)})`;
  }
  return label;
}

// [weather-aware] Builds the instruction that asks Claude to reason about the
// destinations' typical seasonal climate for the travel month(s). This is
// climate/season knowledge, NOT a live forecast.
function seasonalContext(
  destinations: DestinationContext[],
  travelMonths: string[],
): string {
  if (destinations.length === 0) return "";
  const places = destinations.map(destinationLabel).join("; ");
  const months = travelMonths.length > 0
    ? travelMonths.join(" and ")
    : "the travel dates";
  return [
    `The traveler is visiting: ${places}.`,
    `They travel during ${months}.`,
    `Consider the TYPICAL seasonal weather and climate for each destination at`,
    `that time of year — e.g. wet vs. dry season and likely rain, heat and sun`,
    `intensity, humidity, elevation/altitude (cool highlands like Baguio vs.`,
    `hot lowlands or coasts), and any cold spells. Bias the packing items`,
    `toward what that season demands: rain shell / quick-dry clothing and dry`,
    `bags for wet season; sun hat, sunglasses and high-SPF sunscreen for hot,`,
    `sunny coastal trips; warm layers, light jacket for cool highland or`,
    `cold-season trips. Do NOT claim a specific forecast; reason from typical`,
    `conditions for that place and month.`,
  ].join(" ");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const tripTitle: string = body.trip_title ?? "My Trip";
    const startDate: string | null = body.start_date ?? null;
    const endDate: string | null = body.end_date ?? null;
    const activityTitles: string[] = body.activity_titles ?? [];
    const existingItems: string[] = body.existing_items ?? [];

    // [weather-aware] Structured destinations (objects) + travel months.
    // Tolerate the old shape (array of plain strings) for safety.
    const rawDestinations: unknown[] = body.destinations ?? [];
    const destinations: DestinationContext[] = rawDestinations.map((d) =>
      typeof d === "string" ? { name: d } : (d as DestinationContext)
    );
    const travelMonths: string[] = body.travel_months ?? [];

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "ANTHROPIC_API_KEY is not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const anthropic = new Anthropic({ apiKey });

    const dateLine = startDate
      ? `Trip dates: ${startDate}${endDate ? ` to ${endDate}` : ""}.`
      : "Trip dates: not specified.";
    const activitiesLine = activityTitles.length > 0
      ? `Planned activities: ${activityTitles.join(", ")}.`
      : "No specific activities planned yet.";
    const existingLine = existingItems.length > 0
      ? `The list ALREADY contains these items — do NOT repeat them or close duplicates: ${existingItems.join(", ")}.`
      : "The packing list is currently empty.";

    const prompt = [
      `You are a travel packing assistant for trips (primarily in the Philippines).`,
      `Suggest a practical, non-redundant packing list for the following trip.`,
      ``,
      `Trip: "${tripTitle}".`,
      dateLine,
      activitiesLine,
      // [weather-aware] seasonal climate reasoning
      seasonalContext(destinations, travelMonths),
      existingLine,
      ``,
      `Return ONLY valid JSON of the form:`,
      `{ "items": [ { "name": "string", "category": "one of ${CATEGORIES.join("|")}" } ] }`,
      `Rules: 8-18 items, concise singular item names, no quantities, no`,
      `explanations, no markdown. Choose the single best-fitting category for`,
      `each item from the allowed list.`,
    ].join("\n");

    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 1024,
      messages: [{ role: "user", content: prompt }],
    });

    const text = message.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("\n")
      .trim();

    // Extract the JSON object even if the model wrapped it in prose/fences.
    const jsonStart = text.indexOf("{");
    const jsonEnd = text.lastIndexOf("}");
    const jsonSlice = jsonStart >= 0 && jsonEnd > jsonStart
      ? text.slice(jsonStart, jsonEnd + 1)
      : text;

    let parsed: { items?: Array<{ name?: string; category?: string }> };
    try {
      parsed = JSON.parse(jsonSlice);
    } catch (_) {
      return new Response(
        JSON.stringify({ error: "Failed to parse AI response", items: [] }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const existingLower = new Set(
      existingItems.map((n) => n.trim().toLowerCase()),
    );
    const seen = new Set<string>();
    const items = (parsed.items ?? [])
      .map((item) => {
        const name = (item.name ?? "").trim();
        const category = CATEGORIES.includes(item.category ?? "")
          ? item.category
          : "other";
        return { name, category };
      })
      .filter((item) => item.name.length > 0)
      .filter((item) => {
        const key = item.name.toLowerCase();
        if (existingLower.has(key) || seen.has(key)) return false;
        seen.add(key);
        return true;
      });

    return new Response(
      JSON.stringify({ items }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("generate-packing-suggestions error:", error);
    return new Response(
      JSON.stringify({ error: String(error), items: [] }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
