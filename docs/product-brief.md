# ToneAmp — Product Brief

## Problem

Guitar players constantly hear tones they want to reproduce — on records, in videos, at jams — but translating "that sound" into concrete amp knob positions is hard. The knowledge exists, but it's scattered across forum threads, YouTube videos, and gear-magazine interviews. There is no fast, trustworthy, mobile-native way to go from *song* → *settings*.

## Vision

Point your phone at the music. Get the tone. ToneAmp is the fastest path from hearing a guitar sound to dialing it in: identify or search a song, and see the amp, the knobs, the pickup, and the pedals — presented as beautifully as an Apple first-party app.

## Target users

| Persona | Description | Primary need |
| --- | --- | --- |
| **The Bedroom Player** | Intermediate hobbyist learning songs at home | "What do I set my amp to for this song?" |
| **The Cover Band Guitarist** | Gigging player covering many artists per set | Fast lookup, favorites for the setlist |
| **The Tone Chaser** | Gear enthusiast who tweaks endlessly | Trustworthy reference points, gear context |

## Key features

### MVP (this release)
1. **Tone Library** — curated songs, each with 1+ tones (e.g. clean verse vs. distorted chorus), amp model, knob settings (gain/bass/mid/treble/presence/reverb), guitar & pickup, effects chain, playing notes.
2. **Search & browse** — instant search by title/artist, genre filter, alphabetical browse.
3. **Identify with ShazamKit** — one-tap listening; recognized songs deep-link into their tone page; graceful "we don't have this tone yet" fallback showing what was heard.
4. **Favorites** — locally persisted starred songs.
5. **Native experience** — 100% SwiftUI, HIG-compliant navigation, dark mode, Dynamic Type, haptic feedback.

### Post-MVP (explicitly out of scope now)
- Community-submitted and -voted tone presets (requires backend + accounts)
- Amp-specific translation ("show me this tone on *my* Katana 50")
- AI tone matching from raw audio analysis
- Tone audio preview / IR playback
- iPad & macOS layouts, widgets, App Intents ("Hey Siri, what's the tone for…")

## Success criteria (MVP)

- A user can go from launching the app to reading a song's amp settings in **≤ 3 taps**.
- Identify flow: recognized library song lands on its tone page with **zero manual input**.
- App runs offline for everything except ShazamKit matching.
- UI passes the "squint test" next to Apple Music / Notes: system fonts, colors, spacing, and navigation idioms throughout.

## Monetization (future thinking, not built)

Free with a starter catalog; subscription unlocks the full catalog and community tones. Nothing in the MVP architecture blocks this.
