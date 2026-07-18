# ToneAmp — Build Tasks

Status legend: `[ ]` todo · `[x]` done · `[~]` partial/blocked (see note)

## Phase 0 — Planning & docs
- [x] Product brief (vision, personas, key features, success criteria) → `docs/product-brief.md`
- [x] Epics & user stories with acceptance criteria → `docs/epics.md`
- [x] Architecture doc → `docs/architecture.md`
- [x] Native design guidelines → `docs/design.md`
- [x] README + this task list

## Phase 1 — Project scaffold
- [x] Xcode project (`objectVersion 77`, synchronized folder, iOS 17.0 target, iPhone portrait)
- [x] Build settings: generated Info.plist, mic usage description, accent color, app icon placeholder
- [x] Shared scheme for CI/`xcodebuild`
- [x] Asset catalog (AccentColor = system orange, AppIcon placeholder)

## Phase 2 — Models & data
- [x] `Song`, `Tone`, `AmpSettings`, `EffectPedal` + `Genre`, `ToneCharacter`, `EffectType` enums (Codable, stable string IDs)
- [x] Seed catalog: 17 iconic guitar songs, 18 tones — **every tone carries its pedal chain** (name, type, setting hint) per user requirement; "no pedals" is an explicit state, not an omission

## Phase 3 — Stores
- [x] `LibraryStore`: sorted catalog, search (title/artist), genre filter, normalized fuzzy match for Shazam results
- [x] `FavoritesStore`: toggle/contains, `UserDefaults` persistence

## Phase 4 — Views
- [x] `RootView` tab bar (Library / Identify / Favorites)
- [x] Library: song list, rows with genre artwork, `.searchable`, genre filter menu, no-results state
- [x] Song detail: header, favorite toggle (toolbar + haptic), tone list
- [x] Tone detail: amp row + character badge, knob panel, guitar/pickup, **Pedals & Effects section** with per-pedal type badge and setting hint, notes
- [x] Amp panel: custom read-only `KnobView` (270° sweep, ticks, a11y labels), adaptive grid
- [x] Identify: pulsing listen button, permission-denied state with Open Settings, match card → deep link, no-match/error states, success haptic
- [x] Favorites: starred list, swipe to unfavorite, `ContentUnavailableView` empty state

## Phase 5 — ShazamKit
- [x] `ShazamMatcher` (`SHManagedSession`, mic permission flow, state machine, cancellation)
- [x] Catalog fuzzy-matching of matched media items

## Phase 6 — Verification
- [x] Syntax gate: `swiftc -parse` clean on all 12 sources; pbxproj plist-lints OK; asset JSON + scheme XML validated
- [~] Full `xcodebuild` on iOS Simulator — **blocked on this machine**: only Command Line Tools installed, no Xcode.app. Run `xcodebuild -project ToneAmp.xcodeproj -scheme ToneAmp -destination 'generic/platform=iOS Simulator' build` after installing Xcode.
- [x] Manual QA checklist documented (below)

## Phase 7 — v0.2 (user feedback round, 2026-07-18)
- [x] **Pedal depth**: `EffectPedal` now has structured `controls` (per-knob 0–10 values) + a free-text note; catalog updated so every pedal shows its actual knob positions (DS-1: Dist 8/Tone 5/Level 6, Big Muff: Sustain 7/Tone 4/Volume 6, …)
- [x] **More native UI**: amp knobs and pedal knobs re-rendered with the system circular `Gauge` (`.accessoryCircular`, Watch-complication style, gradient tints — Gain sweeps green→red); pedals get Settings-style tinted icon squares; SF Rounded digits
- [x] **Library**: "Featured" horizontal shelf (`scrollTargetBehavior(.viewAligned)`) on the browse screen
- [x] **Song page**: Apple Music-style centered hero header (large artwork, shadow, genre chip); star button bounces via `symbolEffect`
- [x] **Identify**: `shazam.logo.fill` animates with `variableColor` while listening; `session.prepare()` called before matching
- [x] **Shazam diagnostics**: `.failed` state now carries the raw `NSError` domain + code, shown on screen (selectable) and printed to console — next failure will name the actual cause
- [ ] **Shazam root cause**: needs the on-device error code from the new diagnostic line. Likely candidates: no network/VPN (most common), or `com.apple.ShazamKit error 202` (match attempt failed — can indicate the App ID lacks the ShazamKit app service, e.g. on some free personal teams)

## Phase 8 — v0.3: Any-song tone discovery (2026-07-18)
- [x] **`ToneService`** — Claude Messages API (`claude-opus-4-8`) via URLSession; structured outputs (`output_config.format` + JSON schema) guarantee schema-valid JSON; adaptive thinking; handles refusal/truncation/HTTP errors with readable messages
- [x] **API key storage** — iOS Keychain (`KeychainStore`), entered in a new Settings screen (gear icon in Library); never hardcoded, sent only to `api.anthropic.com`
- [x] **Found-song persistence** — `Song.source` (curated/generated), found songs saved to Documents/found-songs.json, merged into library/search/favorites; "Remove All Found Songs" in Settings
- [x] **Library flow** — searching for an unknown song shows "Find "query" with AI"; result opens the song page and joins the library; "AI-generated starting point" badge on song pages
- [x] **Identify flow** — Shazam match not in library shows "Get Tone with AI"; generated tone deep-links immediately
- [x] Syntax gate re-run: all sources parse; embedded JSON schema validated
- [ ] On-device test: needs the user's Anthropic API key (console.anthropic.com → Settings screen in app)

## Phase 9 — v0.4: Community pivot (2026-07-18)
- [x] **LLM removed** — `ToneService`, API-key settings, and found-songs persistence deleted
- [x] **Canonical songs via iTunes Search API** — `MusicSearchService` + `CatalogSong` (no key, dedupe, genre mapping, 600px artwork); song names can't be free-typed
- [x] **Album artwork everywhere** — `SongArtworkView` now loads real art via `AsyncImage` (genre gradient fallback); `Song.artworkURL` added
- [x] **CloudKit community** — `CommunityService`: publish tones, browse per-song / recent / top-rated, 1–5 star ratings with one-per-user dedupe and aggregate updates
- [x] **Community tab** — song search → song page (artwork hero, tone list, "Add Your Tone") → tone editor (sliders, pedal builder with per-knob controls) → tone detail with interactive rating
- [x] **Sign in with Apple** — `SessionStore` (Keychain user ID), onboarding sign-in page + reusable `SignInSheet` gating publish/rate; guest browsing allowed; Settings shows account
- [x] **Onboarding** — 3 animated pages (animated gradient, symbol bounce effects, spring page transitions) + login page; shown once
- [x] **Animation pass** — knob dials sweep up on appear, featured shelf `scrollTransition` scale/fade, rating-star bounce, onboarding gradient
- [x] **Entitlements** — `ToneAmp.entitlements` (Sign in with Apple + CloudKit container `iCloud.com.netnucleus.toneamp`) wired via `CODE_SIGN_ENTITLEMENTS` (paid team confirmed)
- [x] Identify miss now routes to "Find in Community" (iTunes lookup → community song page)
- [ ] **CloudKit Console setup (one-time, after first run)**: in the container's Development environment mark `PublishedTone.trackID` Queryable and enable `creationDate` sort; deploy schema to Production before shipping
- [ ] On-device test of publish → rate → browse loop (needs iCloud signed in on the phone)
- [ ] Monetization plan (deferred by user — see product-brief)

## Phase 10 — v0.4.1: Feedback fixes (2026-07-18)
- [x] **"Community unavailable" fixed** — removed the server-side `creationDate` sort (needed an index fresh containers lack; now sorted client-side) and treat missing record type (`unknownItem`/`invalidArguments`) as an empty community instead of an error; browse-all query now uses `trackID > 0`. CloudKit Console indexing is no longer required for first run.
- [x] **Curated songs get real artwork** — `LibraryStore.loadArtworkIfNeeded()` looks each catalog song up on the iTunes API once (250 ms pacing, cached forever in UserDefaults); verified the API returns art for catalog titles
- [x] **Library redesign** — featured cards now show album artwork with a legibility scrim (Apple Music editorial style), genre filter moved from hidden toolbar menu to horizontal chips, prominent section headers, richer song rows (52 pt art with shadow, semibold titles, "N tones" pill)

## Phase 11 — v0.5: Pro "Identify Tones" + 1000-song catalog (2026-07-18)
- [x] **Pro feature: Identify Tones** — gradient PRO button on every community song page; non-Pro users get a teaser sheet; Pro toggle (preview until StoreKit) in Settings
- [x] **AI tone engine** — `AIToneService` calls Claude (`claude-opus-4-8`) with structured outputs: the reply is schema-constrained JSON (characters/effect types locked to app enums) so parsing can't fail — the "prompt engineering" is the schema + a tight system prompt
- [x] **Magical loading screen** — breathing gradient orb around the album art, orbiting angular-gradient ring, variable-color sparkles, shimmering progress bar, cycling status lines ("Listening to the record…", "Chasing the amp settings…")
- [x] **Results flow** — 1–3 tones rendered with the shared amp-gauge/pedal UI, each with one-tap "Publish to Community"
- [x] **Seed catalog: 1380 songs** — hand-authored song list (≈1080 international + ≈300 Turkish: Duman, Teoman, Şebnem Ferah, Barış Manço, Cem Karaca, Erkin Koray, maNga, Pentagram, mor ve ötesi, Athena, Altın Gün…), each with a template-derived starter tone (era/genre-appropriate amp, deterministic settings, pedal chain, notes)
- [x] **New genre**: Anadolu Rock (chips, badges, tints all pick it up automatically)
- [x] Generator canonicalizes every song against the iTunes API (TR storefront for Turkish) — real album artwork + album names baked into `SeedCatalog.json`, bundled as a resource and merged at launch (hand-checked songs win on conflict)
- [ ] Seed generation finishing in background — verify JSON count/decode when done

## Phase 12 — v0.5.1: Icon, GitHub, Shazam diagnosis (2026-07-18)
- [x] **App icon** — programmatically rendered (CoreGraphics → 1024px PNG): amp knob cranked to the upper right, tick gap at the bottom, orange-to-red tolex gradient; renderer kept in the session scratchpad, output wired into `AppIcon.appiconset`
- [x] **Git** — repo initialized (`main`), Xcode `.gitignore`, remote `git@github.com:aybarsyildiz/toneamp.git`, SSH auth verified
- [x] **Shazam root cause found** — user's error shows the match request to `api.shazam.apple.com/v1/catalog/TR/match` failing with "Reached max retry count (0/0)": audio capture and signature generation succeed; the HTTPS call to Shazam's backend is blocked/failing at the network layer. Not app code. Likely: VPN/Private Relay/DNS content blocker (AdGuard-style profiles block Shazam domains) or restrictive Wi-Fi. Test: toggle VPN off, try cellular data.
- [ ] Seed regeneration (per-artist iTunes batching after per-song lookups hit 403 rate limits) → validate JSON → commit + push

## Phase 13 — v0.6: MVP sprint while the user is away (2026-07-18)
- [x] **Personalization: My Rig** — guitars / amp / pedals selection (`RigStore`, UserDefaults-persisted); collected in a new animated onboarding page and editable in Profile
- [x] **Rig-aware tips** — `RigAdvisor` rules engine translates every tone to the user's gear (pickup ↔ pickup, amp-family EQ shifts, missing-pedal substitutions); "For Your Rig" section on curated, community, and AI tone screens
- [x] **New Profile tab** — gradient avatar with initials, PRO badge, stat tiles (favorites / published / catalog size), My Rig summary + editor, My Published Tones (CloudKit query by author), Settings entry
- [x] **Tone of the Day** — deterministic daily hero banner in the Library
- [x] **Identify history** — last 10 Shazam matches persisted, shown as tappable recents that jump into the Community song page
- [x] **Share tones** — ShareLink on all tone detail screens exporting a formatted plain-text tone sheet
- [x] **Onboarding v2** — new "What's Your Rig?" page (white chip grid on the animated gradient); Settings gains "Replay Onboarding"
- [x] Gold tones applied cleanly in a dry run: **354 songs** hand-upgraded, 0 key misses; full JSON validated (1380 songs, 0 schema errors)
- [x] Parse gate: all 30 Swift files clean
- [ ] Final: apply gold tones to the artwork-enriched SeedCatalog.json, validate, commit, push

## Manual QA checklist (run in Xcode)
- [ ] Library search: "back" → Back in Black; empty query restores full list
- [ ] Genre filter: Metal shows only metal songs; clearing restores
- [ ] Song → tone → knobs render values matching the catalog
- [ ] Favorite from toolbar and swipe; relaunch app → favorites persist
- [ ] Identify: mic prompt appears once; play a catalog song → lands on song page
- [ ] Identify: deny mic → settings screen appears; Open Settings works
- [ ] Dark mode + largest Dynamic Type size: all screens legible
