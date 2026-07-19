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
wrangler secret put ANTHROPIC_API_KEY   # paste the key from console.anthropic.com
wrangler secret put APP_TOKEN           # any long random string, e.g. `openssl rand -hex 24`
wrangler deploy
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

## Notes

- Rotating the key: `wrangler secret put ANTHROPIC_API_KEY` again — no app update needed.
- Spend protection: set a monthly workspace spend limit at console.anthropic.com;
  the Worker also caps max_tokens per request.
- Usage visibility: Cloudflare dashboard → Workers → toneamp-proxy → metrics.
