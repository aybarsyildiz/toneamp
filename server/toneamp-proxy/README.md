# ToneAmp tone-engine proxy

The App Store build must never contain an Anthropic API key. This Cloudflare
Worker holds the key server-side: the app sends Messages API bodies to the
Worker, the Worker injects the key, pins the model (`claude-opus-4-8`), caps
`max_tokens`, and streams the response back.

## Deploy (one time, ~5 minutes)

```sh
cd server/toneamp-proxy
npm install -g wrangler          # if not installed
wrangler login                   # opens browser → Cloudflare account (free tier is fine)
wrangler kv namespace create USAGE      # rate-limit storage; paste the printed id into wrangler.toml
wrangler deploy                         # deploy first so the worker exists…
wrangler secret put ANTHROPIC_API_KEY   # …then attach the key from console.anthropic.com
wrangler secret put APP_TOKEN           # any long random string, e.g. `openssl rand -hex 24`
```

`wrangler deploy` prints the Worker URL, e.g.
`https://toneamp-proxy.<your-subdomain>.workers.dev`.

## Point the app at it

Add to `ToneAmp/Secrets.plist` (gitignored):

```xml
<key>ToneProxyURL</key>
<string>https://toneamp-proxy.<your-subdomain>.workers.dev</string>
<key>ToneProxyToken</key>
<string>the same APP_TOKEN value</string>
```

When `ToneProxyURL` is present the app sends all tone-engine requests there
with no client-side key — `AnthropicAPIKey` in Secrets.plist and the
Settings key field are then only dev fallbacks and can be removed.

## Rate limits (edit constants at the top of worker.js)

- `DAILY_LIMIT = 25` — AI generations per signed-in user per UTC day.
  At roughly $0.08–0.12 per generation, a maxed-out user costs ~$2–3/day;
  in practice almost nobody hits 25.
- `GLOBAL_DAILY_LIMIT = 2000` — whole-app ceiling (~$160–240/day worst case),
  the runaway/abuse backstop. Raise it as the user base grows.
- Limits only apply when the USAGE KV namespace is configured; without it
  the Worker still runs, just unlimited.

## Notes

- Rotating the key: `wrangler secret put ANTHROPIC_API_KEY` again — no app update needed.
- Spend protection: also set a monthly workspace spend limit at console.anthropic.com;
  the Worker additionally caps max_tokens per request.
- Usage visibility: Cloudflare dashboard → Workers → toneamp-proxy → metrics.
