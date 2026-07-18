# ToneAmp — Design Guidelines (Native Apple Feel)

The bar: put ToneAmp next to Apple Music, Notes, and Fitness — it should be indistinguishable in *how* it works and only distinguishable in *what* it does. Every decision below traces to the Human Interface Guidelines.

## Structure & navigation

- **`TabView` with 3 tabs** — Library, Identify, Favorites. Flat, predictable, standard.
- **`NavigationStack` per tab** with large titles (`Library`, `Identify`, `Favorites`); detail pages use inline titles. System back behavior everywhere — no custom chrome, no hamburger menus.
- **Search lives where Apple puts it**: `.searchable` attached to the Library list, appearing under the large title, with the standard pull-down reveal.

## Color & materials

- **Semantic colors only**: `Color(.systemGroupedBackground)`, `.secondary`, tints via `.tint`. No hard-coded hex backgrounds → dark mode is automatic and correct.
- **Accent color: system orange** — evokes tube glow and vintage amp tolex without breaking the system palette. Set once in the asset catalog; every interactive element inherits it.
- **Genre identity via gradients**: song "artwork" is a system-gradient placeholder keyed by genre (rock = orange, metal = indigo, grunge = teal…), with an SF Symbol overlay. Consistent, legal, and dark-mode safe.

## Typography

- **System font only** (SF Pro via default `Font` styles): `.title2.bold()` for song headers, `.body` for content, `.caption`/`.caption2` for metadata, `.monospacedDigit()` for knob values so they don't jitter.
- **Dynamic Type respected** — no fixed font sizes anywhere; layouts use stacks and grids that reflow.

## Iconography

SF Symbols exclusively — the fastest way to look native:

| Concept | Symbol |
| --- | --- |
| Library tab | `music.note.list` |
| Identify tab | `shazam.logo.fill` |
| Favorites tab / star | `star` / `star.fill` |
| Amp | `amplifier` |
| Guitar / pickup | `guitars.fill` |
| Effects | per-type (`bolt.fill`, `clock.arrow.circlepath`, `water.waves`, …) |
| Genre filter | `line.3.horizontal.decrease.circle` |

## The amp panel (the one signature element)

Native apps earn one custom element when the domain demands it (Fitness rings, Weather charts). Ours is the **knob**:

- Read-only dial, 270° sweep (-135°…+135°) like real amp hardware, 11 tick marks, hardware-style radial gradient cap that adapts to light/dark.
- Value shown as a number under each knob (`6.5`) — the knob is recognition, the number is precision.
- Laid out in an adaptive `LazyVGrid` inside a standard inset-grouped section, so the custom element still lives inside system furniture.
- Each knob exposes a proper accessibility label/value ("Gain, 6.5 of 10").

## States & feedback

- **Empty states**: `ContentUnavailableView` everywhere it applies (no favorites yet, no search results, mic denied) — the exact component system apps use.
- **Haptics**: `.sensoryFeedback(.success…)` on song match, `.selection` on favorite toggle. Subtle, system-standard.
- **Identify animation**: soft pulsing rings behind the Shazam button while listening — motion communicates state, respects Reduce Motion by keeping the static state legible.
- **Permission UX**: mic denial is a first-class screen with an "Open Settings" button, not a dead end.

## Interaction details

- Swipe actions for favoriting in lists (leading, star, orange tint) — discoverable and standard.
- Rows navigate with `NavigationLink`; chevrons come from the system, never drawn.
- Portrait-only on iPhone for MVP (tone pages are vertical reading surfaces); iPad/rotation revisited post-MVP.

## Writing style

Apple-voice microcopy: short, sentence case, no exclamation marks, no jargon. "No tone yet" not "Oops! Tone unavailable!!". Buttons are verbs ("Identify", "Open Settings").
