/**
 * ToneAmp tone-engine proxy — Cloudflare Worker.
 *
 * The app POSTs Anthropic Messages API bodies here instead of to
 * api.anthropic.com; the Worker injects the API key (stored as a
 * Cloudflare secret, never shipped in the app), pins the model, and
 * forwards the response unchanged. Deploy steps in README.md.
 */
const UPSTREAM = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-opus-4-8";
const MAX_TOKENS_CAP = 8000;
const DAILY_LIMIT = 25; // generations per user per UTC day
const GLOBAL_DAILY_LIMIT = 2000; // whole-app runaway-spend guard

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json(405, { error: { message: "POST only" } });
    }
    // Optional shared secret: set APP_TOKEN to require the app's
    // x-toneamp-token header (basic abuse protection).
    if (env.APP_TOKEN) {
      if (request.headers.get("x-toneamp-token") !== env.APP_TOKEN) {
        return json(401, { error: { message: "Unauthorized" } });
      }
    }

    // Rate limiting via KV (skipped when the USAGE binding isn't set up).
    if (env.USAGE) {
      const user = request.headers.get("x-toneamp-user") || "anonymous";
      const day = new Date().toISOString().slice(0, 10);
      const userKey = `u:${user}:${day}`;
      const globalKey = `g:${day}`;
      const [userCount, globalCount] = await Promise.all([
        env.USAGE.get(userKey),
        env.USAGE.get(globalKey),
      ]);
      if (parseInt(globalCount ?? "0", 10) >= GLOBAL_DAILY_LIMIT) {
        return json(429, {
          error: { message: "The tone engine is at capacity today — try again tomorrow." },
        });
      }
      if (parseInt(userCount ?? "0", 10) >= DAILY_LIMIT) {
        return json(429, {
          error: { message: `Daily limit reached (${DAILY_LIMIT} AI generations). It resets at midnight UTC.` },
        });
      }
      await Promise.all([
        env.USAGE.put(userKey, String(parseInt(userCount ?? "0", 10) + 1), { expirationTtl: 172800 }),
        env.USAGE.put(globalKey, String(parseInt(globalCount ?? "0", 10) + 1), { expirationTtl: 172800 }),
      ]);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: { message: "Body must be JSON" } });
    }

    // The proxy, not the client, decides model and limits.
    body.model = MODEL;
    body.max_tokens = Math.min(body.max_tokens ?? MAX_TOKENS_CAP, MAX_TOKENS_CAP);

    const upstream = await fetch(UPSTREAM, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });

    return new Response(upstream.body, {
      status: upstream.status,
      headers: { "content-type": "application/json" },
    });
  },
};

function json(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}
