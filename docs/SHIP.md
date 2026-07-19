# Ship checklist — one step at a time

Do these in order. Each step is small. Check it off, move to the next.
(Steps marked ✅ CODE are already done in the repo.)

## Part 1 — The server (15 min, one sitting)

- [ ] 1. Terminal: `cd server/toneamp-proxy && npm install -g wrangler`
- [ ] 2. `wrangler login` → browser opens → sign up/log in to Cloudflare (free)
- [ ] 3. `wrangler kv namespace create USAGE` → copy the printed `id`
- [ ] 4. Open `wrangler.toml`, uncomment the kv block, paste the id
- [ ] 5. `wrangler deploy` → COPY THE URL it prints
- [ ] 6. `wrangler secret put ANTHROPIC_API_KEY` → paste your sk-ant key
- [ ] 7. `wrangler secret put APP_TOKEN` → paste output of `openssl rand -hex 24` (save it!)
- [ ] 8. Open the URL from step 5 in Safari → you should see the support page. Add `/privacy` → privacy policy. Done = server finished forever.

## Part 2 — Point the app at the server (2 min)

- [ ] 9. Open `ToneAmp/Secrets.plist` in Xcode, add:
      `ToneProxyURL` = the URL from step 5
      `ToneProxyToken` = the token from step 7
- [ ] 10. Delete the `AnthropicAPIKey` entry (no key ships in the app now)
- [ ] 11. Build to your phone. Test Identify Tones → must still work (now via your server).

## Part 3 — App Store Connect setup (30 min, can split)

- [ ] 12. appstoreconnect.apple.com → My Apps → "+" → New App → iOS,
      name `ToneAmp: Guitar Tone Finder`, bundle `com.netnucleus.toneampapp`
- [ ] 12b. Business (Agreements) → sign the **Paid Applications Agreement**
      + fill banking & tax info. WITHOUT THIS SUBSCRIPTIONS CANNOT GO LIVE
      and Apple can't pay you. Do it early — bank verification takes days.
- [ ] 13. Monetization → Subscriptions → create group + 2 products
      EXACTLY as written in `docs/appstore/metadata.md` (IDs must match!)
- [ ] 14. App Information → paste name/subtitle/category from metadata.md
- [ ] 15. App Privacy → answer per metadata.md (User ID + User Content, no tracking)
- [ ] 16. Support URL + Privacy URL = your worker URL + `/support`, `/privacy`

## Part 4 — CloudKit + capabilities (10 min)

- [ ] 17. icloud.developer.apple.com → your container → **Deploy Schema Changes to Production** (this includes the new ToneReport type — publish a tone and file one test report from the app FIRST so the type exists)
- [ ] 18. developer.apple.com → Identifiers → com.netnucleus.toneampapp → App Services → ShazamKit ticked (done earlier — just verify)

## Part 5 — Screenshots (20 min)

- [ ] 19. On your iPhone, take the 6 screenshots listed at the bottom of `docs/appstore/metadata.md`
- [ ] 20. AirDrop them to the Mac into `appstore/raw/` named `01.png` … `06.png`
- [ ] 21. Run `python3 tools/frame_screenshots.py` → upload `appstore/framed/*` to App Store Connect

## Part 6 — Archive & submit (30 min + review wait)

- [ ] 22. Xcode: set version 1.0, build 1 → Product → Archive → Distribute → App Store Connect
- [ ] 23. In App Store Connect: select the build, paste description/keywords/promo text from metadata.md, paste the Review Notes
- [ ] 24. Submit for Review. Typical wait: 24–48h.
- [ ] 25. While waiting: TestFlight the same build to yourself + friends (HeadRush friend!)

## If review rejects

Don't panic — read the rejection reason, it's usually one specific thing.
Paste it to Claude and we fix it same-day.
