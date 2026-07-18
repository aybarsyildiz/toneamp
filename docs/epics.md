# ToneAmp — Epics & User Stories

Legend: ✅ in MVP · 🔮 post-MVP

---

## E1 — Tone Library & Browse ✅

> As a guitarist, I want to browse and search songs so I can find the tone I'm after.

| ID | Story | Acceptance criteria |
| --- | --- | --- |
| E1.S1 | As a user I can browse a list of songs with title, artist and genre artwork | Library tab shows all songs alphabetically in a native list; each row has artwork, title, artist |
| E1.S2 | As a user I can search by song title or artist | `.searchable` field filters live; empty results show a native "No Results" state |
| E1.S3 | As a user I can filter by genre | Toolbar filter menu with genre picker; active filter is visually indicated and clearable |
| E1.S4 | As a user I can open a song and see its tones | Song page shows header (artwork, title, artist, album, year) and a list of its tones |

## E2 — Tone Detail ✅

> As a guitarist, I want exact amp settings presented visually so I can dial them in on my hardware.

| ID | Story | Acceptance criteria |
| --- | --- | --- |
| E2.S1 | As a user I can read amp settings as knobs | Amp panel renders gain/bass/mid/treble (+presence/reverb when defined) as 0–10 knobs with numeric values |
| E2.S2 | As a user I know which amp and character the tone uses | Amp model row + tone character badge (Clean / Crunch / Overdrive / High Gain / Fuzz / Lead) |
| E2.S3 | As a user I know which guitar & pickup to use | Guitar and pickup-position rows with SF Symbol iconography |
| E2.S4 | As a user I can see the effects chain in order | Ordered effect list with type icon, pedal name, and setting hint |
| E2.S5 | As a user I get playing/context notes | Notes section with tips (tuning, technique, studio context) |

## E3 — Identify with ShazamKit ✅

> As a guitarist, when a song is playing, I want the app to recognize it and take me straight to its tone.

| ID | Story | Acceptance criteria |
| --- | --- | --- |
| E3.S1 | As a user I can tap a button to start listening | Large Shazam-style button; pulsing animation + live status while listening; tap again cancels |
| E3.S2 | As a user I'm asked for mic permission properly | System mic prompt with clear usage description; denied state shows explanation + "Open Settings" |
| E3.S3 | As a user a recognized library song takes me to its tones | Match is fuzzy-matched (normalized title+artist) against the catalog; result card deep-links to the song page; success haptic |
| E3.S4 | As a user I get a graceful miss | Recognized-but-uncatalogued songs show title/artist/artwork with "no tone yet"; no-match and errors show friendly retry states |

## E4 — Favorites ✅

> As a gigging guitarist, I want my setlist tones one tap away.

| ID | Story | Acceptance criteria |
| --- | --- | --- |
| E4.S1 | As a user I can star/unstar a song anywhere I see it | Star toggle on song page toolbar + swipe action in lists; haptic on toggle |
| E4.S2 | As a user my favorites persist | Stored in `UserDefaults`; survive relaunch |
| E4.S3 | As a user I have a Favorites tab | Native list of starred songs; `ContentUnavailableView` empty state |

## E5 — Native Apple Experience ✅ (cross-cutting)

| ID | Story | Acceptance criteria |
| --- | --- | --- |
| E5.S1 | Navigation feels like a system app | `TabView` + `NavigationStack`, large titles, standard back behavior |
| E5.S2 | Visuals are system-native | SF Symbols only, system colors/materials, inset-grouped lists, no custom fonts |
| E5.S3 | Accessibility | Dynamic Type respected; knobs expose value via accessibility labels |
| E5.S4 | Dark mode | Every screen correct in light & dark with semantic colors |
| E5.S5 | Feedback | `.sensoryFeedback` haptics on favorite toggle and successful match |

## E6 — Community Tones 🔮

Backend catalog, accounts, tone submission/voting, moderation. Requires server + sync layer; the `Codable` model and store abstraction are already shaped for a remote source.

## E7 — Personal Rig Translation 🔮

User describes their amp; settings are translated to its controls (e.g. Marshall JCM800 recipe → Boss Katana). Needs an amp-capability database and mapping engine.

## E8 — Tone Intelligence 🔮

On-device audio analysis of what's playing to *suggest* EQ/gain even for unknown songs; Siri/App Intents entry points; widgets showing "tone of the day".
