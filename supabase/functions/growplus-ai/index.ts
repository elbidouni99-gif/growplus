// Deploy with Supabase CLI: supabase functions deploy growplus-ai
// Set secret: supabase secrets set OPENAI_API_KEY=...
// Never expose this provider key in frontend code.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "POST required" }), {
    status: 405, headers: { ...cors, "Content-Type": "application/json" },
  });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!supabaseUrl || !anonKey || !openaiKey) return new Response(JSON.stringify({
    error: "AI service is not configured. Set the required Supabase secrets first.",
  }), { status: 503, headers: { ...cors, "Content-Type": "application/json" } });
  if (!authHeader) return new Response(JSON.stringify({ error: "Sign in is required." }), {
    status: 401, headers: { ...cors, "Content-Type": "application/json" },
  });

  const sb = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await sb.auth.getUser();
  if (userError || !user) return new Response(JSON.stringify({ error: "Invalid session." }), {
    status: 401, headers: { ...cors, "Content-Type": "application/json" },
  });

  try {
    const body = await req.json();
    const prompt = typeof body?.prompt === "string" ? body.prompt.trim() : "";
    if (!prompt || prompt.length > 2000) return new Response(JSON.stringify({
      error: "Prompt must be between 1 and 2000 characters.",
    }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });

    // A small daily quota protects the project from accidental high usage.
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const { count, error: quotaError } = await sb.from("growplus_ai_usage")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", dayStart.toISOString());
    if (quotaError) return new Response(JSON.stringify({
      error: "AI usage table is not configured. Run the Pro SQL migration.",
    }), { status: 503, headers: { ...cors, "Content-Type": "application/json" } });
    if ((count ?? 0) >= 20) return new Response(JSON.stringify({
      error: "Daily AI limit reached (20 requests). Please try again tomorrow.",
    }), { status: 429, headers: { ...cors, "Content-Type": "application/json" } });

    const aiResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${openaiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: Deno.env.get("GROWPLUS_AI_MODEL") || "gpt-4.1-mini",
        instructions: "You are GrowPlus assistant. Help users understand legitimate creator growth, learning, surveys, task rules and account navigation. Never promise earnings, fabricate completed tasks, claim a payout has been sent, request passwords or payment PINs, or encourage fake engagement. Be concise and honest.",
        input: prompt,
        max_output_tokens: 500,
      }),
    });
    const result = await aiResponse.json();
    if (!aiResponse.ok) return new Response(JSON.stringify({
      error: "AI provider request failed.", details: result?.error?.message || "Provider error",
    }), { status: 502, headers: { ...cors, "Content-Type": "application/json" } });

    const answer = Array.isArray(result.output)
      ? result.output.flatMap((item: any) => Array.isArray(item.content) ? item.content : [])
          .filter((item: any) => item.type === "output_text").map((item: any) => item.text).join("\n")
      : "";
    await sb.from("growplus_ai_usage").insert({ user_id: user.id });
    return new Response(JSON.stringify({ answer }), {
      status: 200, headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request or temporary AI error." }), {
      status: 400, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
