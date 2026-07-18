# ToneAmp

**Find the amp settings behind any song's guitar tone.**

ToneAmp is a native iOS app for guitar players who hear a tone they love and want to dial it in on their own amp. Search a curated library of iconic songs — or let the app identify what's playing with ShazamKit — and get the amp model, knob-by-knob settings, guitar/pickup choice, and effects chain that get you closest to the record.

## Key features (MVP)

- **Community tones for any song** — Anyone can publish a tone (amp, knob values, pickup, full pedalboard with per-knob settings) and rate what others share, 1–5 stars. Songs are picked from Apple's iTunes catalog — canonical titles, artists, and real album artwork; no free-typed song names. Backed by CloudKit's public database (no server) with Sign in with Apple for identity; browsing needs no account.
- **Onboarding & sign-in** — Animated first-launch onboarding ending in Sign in with Apple (guest mode available).
- **Tone Library** — Curated, hand-checked catalog of iconic guitar songs, each with one or more tones (intro, rhythm, solo…), amp settings rendered as native circular gauges, pickup/guitar guidance, and a pedalboard with per-knob settings.
- **Search** — Native `.searchable` search over song titles and artists, plus a genre filter and a featured shelf.
- **Identify (ShazamKit)** — Tap to listen, Shazam-style. Recognized library songs deep-link to their tone; unknown ones offer "Get Tone with AI".
- **Favorites** — Star songs to keep your go-to tones one tap away. Persisted locally.
- **My Rig personalization** — Tell ToneAmp your guitars, amp, and pedals (onboarding or Profile); every tone screen adds "For Your Rig" tips that translate the recording's settings to your gear.
- **ToneAmp Pro: Identify Tones** — The AI tone engine builds a researched tone sheet for any song behind a magical loading screen (Claude structured outputs; preview toggle until StoreKit).
- **1,380-song catalog** — Curated gold tones (354 hand-researched, including Turkish rock: Duman, Pentagram, Erkin Koray, mor ve ötesi…) plus template starter tones for the rest, all with iTunes artwork. Tone of the Day, Identify history, tone sharing, and a Profile tab round out the MVP.
- **Native Apple look & feel** — SwiftUI end to end: `NavigationStack`, inset-grouped lists, SF Symbols, system colors and materials, Dynamic Type, dark mode, haptics. It should feel like Apple shipped it.

## Requirements

- Xcode 16 or newer
- iOS 17.0+ (uses `@Observable`, `SHManagedSession`, `ContentUnavailableView`, `.sensoryFeedback`)
- A real device is recommended for the Identify tab (microphone + Shazam catalog access)

## Getting started

1. Open `ToneAmp.xcodeproj` in Xcode.
2. Select the **ToneAmp** scheme and an iOS 17+ simulator or device.
3. Run. No dependencies, no package resolution — everything is first-party Apple frameworks.

> The Identify tab needs microphone permission and network access. On first use, iOS will show the mic permission prompt (usage description is set in build settings).

## Project layout

```
ToneAmp/
├── ToneAmpApp.swift          # App entry point, store injection
├── Models/                   # Song, Tone, AmpSettings, EffectPedal (Codable)
├── Stores/                   # LibraryStore, FavoritesStore (@Observable)
├── Shazam/                   # ShazamMatcher — SHManagedSession wrapper
└── Views/
    ├── RootView.swift        # Tab bar
    ├── Library/              # Browse, search, song detail
    ├── Tone/                 # Tone detail, amp panel, knobs
    ├── Identify/             # ShazamKit UI
    ├── Favorites/            # Starred songs
    └── Shared/               # Artwork, genre styling, badges
```

## Documentation

| Doc | Purpose |
| --- | --- |
| [docs/product-brief.md](docs/product-brief.md) | Vision, users, key features, success criteria |
| [docs/epics.md](docs/epics.md) | Epics, user stories, acceptance criteria, MVP cut line |
| [docs/architecture.md](docs/architecture.md) | App architecture, data flow, ShazamKit integration |
| [docs/design.md](docs/design.md) | Native Apple design guidelines applied to ToneAmp |
| [tasks.md](tasks.md) | Build task list and status |

## Disclaimer

Amp settings in the catalog are community-style approximations intended as starting points — the exact record tone depends on the guitar, amp revision, mics, and studio processing. Song titles and artist names are used as factual metadata.
