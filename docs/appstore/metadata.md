# App Store Connect — copy-paste pack

Everything below is ready to paste into App Store Connect fields.

## App Information

| Field | Value |
|---|---|
| Name (30 max) | `ToneAmp: Guitar Tone Finder` |
| Subtitle (30 max) | `Amp settings for every song` |
| Primary category | Music |
| Secondary category | Education |
| Bundle ID | com.netnucleus.toneamp |
| Age rating | 4+ (answer "None" to all content questions; answer YES to "unrestricted user-generated content" → we have report/hide/block, so select the moderation options) |

## Promotional Text (170 max)

```
1,300+ songs with real amp settings and pedal chains — Turkish and international rock. AI adapts any tone to YOUR exact gear.
```

## Description

```
Ever heard a song and wondered "how do I get THAT tone"? ToneAmp answers it.

THE LIBRARY
Over 1,300 songs — international and Turkish rock, metal, blues, and more — each with a researched tone sheet: the amp, the exact knob positions, the guitar and pickup, and every pedal in the chain with its settings.

IDENTIFY ANY SONG
Hear a tone in the wild? Identify the song instantly (powered by ShazamKit) and jump straight to its tone.

COMMUNITY TONES
Every player hears differently. Publish your own version of a song's tone, rate others, and browse the community's takes — filtered by rating, recency, or tone character.

YOUR RIG
Tell ToneAmp what you play — any guitar, amp, multi-FX, or pedalboard, from a PRS SE to a Boss GT-8 straight into your PC. Your rig lives as a visual signal chain.

TONEAMP PRO
• Identify Tones — AI researches any song in the catalog or beyond and writes a complete tone sheet in seconds.
• Adapt to My Gear — the magic feature: take any tone and have AI translate it onto YOUR exact equipment, block by block on your multi-FX, knob by knob on your amp, with step-by-step instructions.
• Every AI result is saved to your personal tone library.

No ads. No tracking. Made by a guitarist, for guitarists.
```

## Keywords (100 max, comma-separated)

```
guitar,tone,amp,pedal,settings,rig,multifx,helix,overdrive,distortion,rock,metal,gitar,ton
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://<your-worker>.workers.dev/support` |
| Privacy Policy URL | `https://<your-worker>.workers.dev/privacy` |

## App Privacy questionnaire

- **Do you collect data?** Yes.
- **User ID** (the Sign in with Apple identifier): collected, linked to user, purpose = App Functionality. Not used for tracking.
- **User Content** (published tones + display name): collected, linked to user, purpose = App Functionality. Not used for tracking.
- Everything else (location, contacts, purchases, browsing, diagnostics): **not collected**.
- **Tracking:** No.

## Subscriptions (Monetization → Subscriptions)

Create ONE subscription group "ToneAmp Pro", with TWO products:

| Field | Yearly | Monthly |
|---|---|---|
| Product ID | `com.netnucleus.toneamp.pro.yearly` | `com.netnucleus.toneamp.pro.monthly` |
| Reference name | Pro Yearly | Pro Monthly |
| Duration | 1 year | 1 month |
| Price | $29.99 tier | $4.99 tier |
| Intro offer | 7-day free trial | none |
| Display name | ToneAmp Pro (Yearly) | ToneAmp Pro (Monthly) |
| Description | Full AI tone engine, adapted to your gear. | Full AI tone engine, adapted to your gear. |

Product IDs must match EXACTLY — the app hardcodes them in `ProStore.swift`.

## App Review notes (paste into "Notes" box)

```
- Browsing the full tone library needs no account. Sign in with Apple is only
  required to publish or rate community tones.
- Community content moderation: every published tone has a ••• menu with
  Report (spam / misleading / offensive), Hide This Tone, and Block Author.
  Reports are reviewed within 24 hours via CloudKit.
- ToneAmp Pro (auto-renewable subscription) unlocks the AI features
  ("Identify Tones" and "Adapt to My Gear"). These call our server-side
  proxy; no key or account needed on the reviewer's part — a sandbox
  subscription activates them.
- Song identification uses Apple's ShazamKit; microphone access is
  requested only on the Identify tab.
```

## Screenshot shot list (6 shots, portrait)

Take these on an iPhone with Dynamic Island (or the largest iPhone simulator),
save as `appstore/raw/01.png` … `06.png`, then run `python3 tools/frame_screenshots.py`:

1. **Library tab** — scrolled to show Tone of the Day + featured shelf
2. **A song's tone sheet** — e.g. Comfortably Numb: amp panel + pedals visible
3. **Identify tab** — the listening state
4. **AI result** — Identify Tones result list for a song (Pro)
5. **My Rig tab** — a filled signal chain (guitar → effects → output)
6. **Community browse** — song list with ratings, filter menu open if possible
