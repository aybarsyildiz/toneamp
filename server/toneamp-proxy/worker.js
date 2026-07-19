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
    // Public pages: App Store privacy policy + support URL live here too,
    // so no separate website is needed.
    if (request.method === "GET") {
      const path = new URL(request.url).pathname;
      if (path === "/privacy") return html(PRIVACY_HTML);
      if (path === "/support" || path === "/") return html(SUPPORT_HTML);
      return json(404, { error: { message: "Not found" } });
    }
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

function html(body) {
  return new Response(
    `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ToneAmp</title><style>body{font-family:-apple-system,system-ui,sans-serif;max-width:640px;margin:40px auto;padding:0 20px;line-height:1.6;color:#1a1a1a}h1{font-size:1.6em}h2{font-size:1.15em;margin-top:1.6em}@media(prefers-color-scheme:dark){body{background:#111;color:#eee}}</style></head><body>${body}</body></html>`,
    { status: 200, headers: { "content-type": "text/html; charset=utf-8" } }
  );
}

const SUPPORT_HTML = `
<h1>ToneAmp — Support</h1>
<p>ToneAmp shows guitarists how to dial in the tones of real songs — amps, settings, and pedals — and adapts them to your own gear with AI.</p>
<h2>Contact</h2>
<p>Questions, bug reports, or feedback: <a href="mailto:s.aybars.yildiz@gmail.com">s.aybars.yildiz@gmail.com</a>. We usually reply within 48 hours.</p>
<h2>Community content</h2>
<p>Tones published to the community can be reported, hidden, or their author blocked from the ••• menu on any tone page. Reported content is reviewed within 24 hours and removed if it violates our rules (spam, misleading, or offensive content).</p>
<h2>Subscription</h2>
<p>ToneAmp Pro renews automatically. Manage or cancel any time in iOS Settings → your Apple ID → Subscriptions.</p>
<p><a href="/privacy">Privacy Policy</a></p>
`;

const PRIVACY_HTML = `
<h1>ToneAmp — Privacy Policy</h1>
<p>Effective July 2026. ToneAmp is built to collect as little as possible.</p>
<h2>What we collect</h2>
<ul>
<li><b>Sign in with Apple identifier</b> — a random ID Apple gives us when you sign in. Used to attribute the tones you publish and your ratings. We never see your email unless you choose to share it.</li>
<li><b>Content you publish</b> — tones you share to the community (amp settings, pedals, notes, your display name) are public.</li>
<li><b>AI requests</b> — when you use Identify Tones or Adapt to My Gear, the song name and your gear list are sent to our server and processed by Anthropic's Claude API to generate the result. Requests are not used to train models.</li>
<li><b>Your gear and favorites</b> — stored on your device (and your private iCloud where applicable), not on our servers.</li>
</ul>
<h2>What we don't do</h2>
<ul>
<li>No ads, no trackers, no analytics SDKs, no selling of data.</li>
<li>No collection of contacts, location, photos, or microphone audio. Song identification uses Apple's ShazamKit on-device service.</li>
</ul>
<h2>Deletion</h2>
<p>Delete the app to remove local data. To delete your published tones and account identifier, email <a href="mailto:s.aybars.yildiz@gmail.com">s.aybars.yildiz@gmail.com</a> from the device and we'll remove them within 30 days.</p>
<h2>Contact</h2>
<p>NetNucleus — <a href="mailto:s.aybars.yildiz@gmail.com">s.aybars.yildiz@gmail.com</a></p>
`;
