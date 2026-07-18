import Foundation

/// Curated seed catalog. Settings are community-style approximations meant as
/// starting points on a 0–10 scale; the exact record tone also depends on the
/// specific amp revision, guitar, mics, and studio processing.
enum SongCatalog {
    static let songs: [Song] = [
        Song(
            id: "back-in-black",
            title: "Back in Black",
            artist: "AC/DC",
            album: "Back in Black",
            year: 1980,
            genre: .hardRock,
            tones: [
                Tone(
                    id: "back-in-black-rhythm",
                    name: "Main Riff",
                    amp: "Marshall Super Lead (Plexi)",
                    character: .crunch,
                    settings: AmpSettings(gain: 6, bass: 5.5, mid: 6, treble: 6.5, presence: 5),
                    guitar: "Gibson SG",
                    pickup: "Bridge humbucker",
                    pedals: [],
                    notes: "No pedals — this is a cranked Plexi doing all the work. Keep the gain moderate: the riff should clean up when you pick softly and bark when you dig in. Tight, palm-mute-free open chords, and let them ring."
                ),
            ]
        ),
        Song(
            id: "smells-like-teen-spirit",
            title: "Smells Like Teen Spirit",
            artist: "Nirvana",
            album: "Nevermind",
            year: 1991,
            genre: .grunge,
            tones: [
                Tone(
                    id: "slts-verse",
                    name: "Verse (Clean + Chorus)",
                    amp: "Fender Twin Reverb",
                    character: .clean,
                    settings: AmpSettings(gain: 3, bass: 5, mid: 5, treble: 6, reverb: 2.5),
                    guitar: "Fender Mustang / Jaguar",
                    pickup: "Bridge humbucker",
                    pedals: [
                        EffectPedal(
                            name: "EHX Small Clone",
                            type: .chorus,
                            controls: [
                                PedalControl(name: "Rate", value: 3),
                            ],
                            note: "Depth switch up — the watery verse shimmer comes entirely from this pedal."
                        ),
                    ],
                    notes: "The verse is a clean amp with the Small Clone doing the character. Play the two-note pattern softly and let the chorus wobble carry it."
                ),
                Tone(
                    id: "slts-chorus",
                    name: "Chorus (Distortion)",
                    amp: "Fender Twin Reverb",
                    character: .highGain,
                    settings: AmpSettings(gain: 8, bass: 6, mid: 4, treble: 6),
                    guitar: "Fender Mustang / Jaguar",
                    pickup: "Bridge humbucker",
                    pedals: [
                        EffectPedal(
                            name: "Boss DS-1",
                            type: .distortion,
                            controls: [
                                PedalControl(name: "Dist", value: 8),
                                PedalControl(name: "Tone", value: 5),
                                PedalControl(name: "Level", value: 6),
                            ],
                            note: "Set Level so the pedal matches the clean channel volume, then stomp it for the wall of sound."
                        ),
                    ],
                    notes: "Slightly scooped mids, big open power chords, aggressive downstrokes."
                ),
            ]
        ),
        Song(
            id: "sweet-child-o-mine",
            title: "Sweet Child O' Mine",
            artist: "Guns N' Roses",
            album: "Appetite for Destruction",
            year: 1987,
            genre: .hardRock,
            tones: [
                Tone(
                    id: "scom-intro",
                    name: "Intro & Leads",
                    amp: "Marshall JCM800 (modded)",
                    character: .lead,
                    settings: AmpSettings(gain: 7, bass: 5, mid: 6.5, treble: 6, presence: 6, reverb: 2),
                    guitar: "Gibson Les Paul",
                    pickup: "Bridge humbucker",
                    pedals: [
                        EffectPedal(
                            name: "Dunlop Cry Baby",
                            type: .wah,
                            controls: [],
                            note: "Solo section only — rock it with the phrasing, parked mid-sweep for the vocal quality."
                        ),
                    ],
                    notes: "Mid-forward Marshall lead tone with singing sustain. The intro arpeggio wants clarity: moderate gain, precise alternate picking, and let the mids do the talking."
                ),
            ]
        ),
        Song(
            id: "enter-sandman",
            title: "Enter Sandman",
            artist: "Metallica",
            album: "Metallica (The Black Album)",
            year: 1991,
            genre: .metal,
            tones: [
                Tone(
                    id: "enter-sandman-rhythm",
                    name: "Main Riff",
                    amp: "Mesa/Boogie Mark IIC+",
                    character: .highGain,
                    settings: AmpSettings(gain: 8.5, bass: 6.5, mid: 3, treble: 7, presence: 6),
                    guitar: "ESP Explorer (EMG 81)",
                    pickup: "Bridge humbucker (active)",
                    pedals: [
                        EffectPedal(
                            name: "Ibanez Tube Screamer",
                            type: .boost,
                            controls: [
                                PedalControl(name: "Drive", value: 1.5),
                                PedalControl(name: "Tone", value: 5),
                                PedalControl(name: "Level", value: 8.5),
                            ],
                            note: "Not for gain — a nearly-clean boost that tightens the low end. The amp makes the distortion."
                        ),
                    ],
                    notes: "Scooped mids, tight palm mutes, all downstrokes. Standard E tuning."
                ),
            ]
        ),
        Song(
            id: "smoke-on-the-water",
            title: "Smoke on the Water",
            artist: "Deep Purple",
            album: "Machine Head",
            year: 1972,
            genre: .hardRock,
            tones: [
                Tone(
                    id: "sotw-riff",
                    name: "Main Riff",
                    amp: "Marshall Major 200",
                    character: .crunch,
                    settings: AmpSettings(gain: 5.5, bass: 5, mid: 5.5, treble: 6.5),
                    guitar: "Fender Stratocaster",
                    pickup: "Neck single-coil",
                    pedals: [
                        EffectPedal(
                            name: "Hornby Skewes Treble Booster",
                            type: .boost,
                            controls: [
                                PedalControl(name: "Boost", value: 7),
                            ],
                            note: "Always on — pushes the Marshall front end into its natural grind."
                        ),
                    ],
                    notes: "Play the riff with two-finger fourths (not full barre chords), plucked with fingers for that percussive attack. Moderate crunch — it's rounder than you remember."
                ),
            ]
        ),
        Song(
            id: "purple-haze",
            title: "Purple Haze",
            artist: "Jimi Hendrix",
            album: "Are You Experienced",
            year: 1967,
            genre: .psychedelic,
            tones: [
                Tone(
                    id: "purple-haze-main",
                    name: "Riff & Solo",
                    amp: "Marshall Super Lead 100",
                    character: .fuzz,
                    settings: AmpSettings(gain: 6, bass: 5.5, mid: 6, treble: 6.5, presence: 5.5),
                    guitar: "Fender Stratocaster",
                    pickup: "Bridge single-coil",
                    pedals: [
                        EffectPedal(
                            name: "Dallas Arbiter Fuzz Face",
                            type: .fuzz,
                            controls: [
                                PedalControl(name: "Fuzz", value: 8),
                                PedalControl(name: "Volume", value: 7),
                            ],
                            note: "Germanium fuzz — clean up with the guitar's volume knob instead of the pedal."
                        ),
                        EffectPedal(
                            name: "Vox Wah",
                            type: .wah,
                            controls: [],
                            note: "Intro flavor and vocal phrasing accents."
                        ),
                        EffectPedal(
                            name: "Roger Mayer Octavia",
                            type: .octave,
                            controls: [
                                PedalControl(name: "Level", value: 6),
                            ],
                            note: "Solo only — the upper-octave sizzle."
                        ),
                    ],
                    notes: "Fuzz into a loud Marshall. Ride the guitar's volume: full up for the riff, backed off for cleaner passages. Thumb-over Hendrix voicings."
                ),
            ]
        ),
        Song(
            id: "comfortably-numb",
            title: "Comfortably Numb",
            artist: "Pink Floyd",
            album: "The Wall",
            year: 1979,
            genre: .rock,
            tones: [
                Tone(
                    id: "comfortably-numb-solo",
                    name: "Outro Solo",
                    amp: "Hiwatt DR103",
                    character: .lead,
                    settings: AmpSettings(gain: 4, bass: 6, mid: 5, treble: 6, presence: 5, reverb: 2),
                    guitar: "Fender Stratocaster",
                    pickup: "Bridge single-coil",
                    pedals: [
                        EffectPedal(
                            name: "EHX Big Muff Pi",
                            type: .fuzz,
                            controls: [
                                PedalControl(name: "Sustain", value: 7),
                                PedalControl(name: "Tone", value: 4),
                                PedalControl(name: "Volume", value: 6),
                            ],
                            note: "The singing core of the solo — sustain from the pedal, headroom from the clean Hiwatt."
                        ),
                        EffectPedal(
                            name: "EHX Electric Mistress",
                            type: .flanger,
                            controls: [
                                PedalControl(name: "Rate", value: 2),
                                PedalControl(name: "Range", value: 5),
                                PedalControl(name: "Color", value: 4),
                            ],
                            note: "Slow and subtle — the liquid width around the notes."
                        ),
                        EffectPedal(
                            name: "Analog Delay",
                            type: .delay,
                            controls: [
                                PedalControl(name: "Time", value: 6),
                                PedalControl(name: "Repeats", value: 4),
                                PedalControl(name: "Mix", value: 3),
                            ],
                            note: "≈450 ms, repeats tucked under the dry signal — space, not echo."
                        ),
                    ],
                    notes: "Huge bends — take your time, every note counts."
                ),
            ]
        ),
        Song(
            id: "nothing-else-matters",
            title: "Nothing Else Matters",
            artist: "Metallica",
            album: "Metallica (The Black Album)",
            year: 1991,
            genre: .metal,
            tones: [
                Tone(
                    id: "nem-intro",
                    name: "Intro (Clean)",
                    amp: "Mesa/Boogie Mark IIC+ (clean channel)",
                    character: .clean,
                    settings: AmpSettings(gain: 2.5, bass: 6, mid: 5, treble: 5.5, reverb: 4),
                    guitar: "ESP (EMG 60 neck)",
                    pickup: "Neck humbucker (active)",
                    pedals: [],
                    notes: "Fingerpicked, no pick, built around open E minor — the open strings ring through the whole intro. Generous reverb, warm neck pickup, gentle dynamics."
                ),
            ]
        ),
        Song(
            id: "sultans-of-swing",
            title: "Sultans of Swing",
            artist: "Dire Straits",
            album: "Dire Straits",
            year: 1978,
            genre: .rock,
            tones: [
                Tone(
                    id: "sultans-lead",
                    name: "Clean Lead",
                    amp: "Fender Vibrolux Reverb",
                    character: .clean,
                    settings: AmpSettings(gain: 3.5, bass: 4.5, mid: 5.5, treble: 6.5, reverb: 3.5),
                    guitar: "Fender Stratocaster",
                    pickup: "Middle + bridge (position 2)",
                    pedals: [
                        EffectPedal(
                            name: "MXR Dyna Comp",
                            type: .compressor,
                            controls: [
                                PedalControl(name: "Output", value: 6),
                                PedalControl(name: "Sensitivity", value: 5),
                            ],
                            note: "Evens out the fingerstyle attack into that smooth, even sustain."
                        ),
                    ],
                    notes: "All fingers, no pick. The quack comes from the in-between pickup position; the smoothness comes from the compressor and a just-breaking-up Fender amp."
                ),
            ]
        ),
        Song(
            id: "la-grange",
            title: "La Grange",
            artist: "ZZ Top",
            album: "Tres Hombres",
            year: 1973,
            genre: .bluesRock,
            tones: [
                Tone(
                    id: "la-grange-riff",
                    name: "Riff & Solo",
                    amp: "Marshall Super Lead",
                    character: .crunch,
                    settings: AmpSettings(gain: 5.5, bass: 4.5, mid: 6, treble: 6.5),
                    guitar: "Gibson Les Paul ('Pearly Gates')",
                    pickup: "Bridge humbucker",
                    pedals: [],
                    notes: "Straight into a crunchy Marshall. The magic is in the right hand: light palm mutes on the A-string shuffle and pinch harmonics for the squeals in the solo."
                ),
            ]
        ),
        Song(
            id: "whole-lotta-love",
            title: "Whole Lotta Love",
            artist: "Led Zeppelin",
            album: "Led Zeppelin II",
            year: 1969,
            genre: .hardRock,
            tones: [
                Tone(
                    id: "wll-riff",
                    name: "Main Riff",
                    amp: "Supro combo (cranked)",
                    character: .crunch,
                    settings: AmpSettings(gain: 6.5, bass: 5, mid: 6.5, treble: 6),
                    guitar: "Gibson Les Paul",
                    pickup: "Bridge humbucker",
                    pedals: [],
                    notes: "A small amp pushed hard, not a big amp with pedals. Mid-heavy, raw, slightly ragged. Keep the riff loose and behind the beat — swagger over precision."
                ),
            ]
        ),
        Song(
            id: "paranoid",
            title: "Paranoid",
            artist: "Black Sabbath",
            album: "Paranoid",
            year: 1970,
            genre: .metal,
            tones: [
                Tone(
                    id: "paranoid-riff",
                    name: "Main Riff",
                    amp: "Laney Supergroup LA100BL",
                    character: .crunch,
                    settings: AmpSettings(gain: 6, bass: 5, mid: 6, treble: 7),
                    guitar: "Gibson SG",
                    pickup: "Bridge humbucker",
                    pedals: [
                        EffectPedal(
                            name: "Dallas Rangemaster",
                            type: .boost,
                            controls: [
                                PedalControl(name: "Boost", value: 8),
                            ],
                            note: "Treble booster always on — slices the Laney into sustain."
                        ),
                    ],
                    notes: "Proto-metal is a boosted, trebly crunch — not modern high gain. Fast downstroke gallop, light touch on the hammer-on figure."
                ),
            ]
        ),
        Song(
            id: "everlong",
            title: "Everlong",
            artist: "Foo Fighters",
            album: "The Colour and the Shape",
            year: 1997,
            genre: .alternative,
            tones: [
                Tone(
                    id: "everlong-rhythm",
                    name: "Rhythm",
                    amp: "Mesa/Boogie Dual Rectifier",
                    character: .highGain,
                    settings: AmpSettings(gain: 7, bass: 6, mid: 5, treble: 6, presence: 5),
                    guitar: "Gibson Trini Lopez (semi-hollow)",
                    pickup: "Bridge humbucker",
                    pedals: [],
                    notes: "Drop D tuning. Big saturated chords, but the semi-hollow body keeps it airy instead of chuggy. Sixteenth-note right hand — endurance is the real setting."
                ),
            ]
        ),
        Song(
            id: "seven-nation-army",
            title: "Seven Nation Army",
            artist: "The White Stripes",
            album: "Elephant",
            year: 2003,
            genre: .alternative,
            tones: [
                Tone(
                    id: "sna-riff",
                    name: "Main Riff",
                    amp: "Fender-style tube combo",
                    character: .fuzz,
                    settings: AmpSettings(gain: 5, bass: 6, mid: 5, treble: 5.5),
                    guitar: "1960s Airline (semi-hollow)",
                    pickup: "Bridge pickup",
                    pedals: [
                        EffectPedal(
                            name: "DigiTech Whammy",
                            type: .octave,
                            controls: [],
                            note: "One octave down mode — this IS the 'bass' sound. There's no bass guitar on the record."
                        ),
                        EffectPedal(
                            name: "EHX Big Muff Pi",
                            type: .fuzz,
                            controls: [
                                PedalControl(name: "Sustain", value: 6),
                                PedalControl(name: "Tone", value: 5),
                                PedalControl(name: "Volume", value: 5),
                            ],
                            note: "Kicks in for the chorus riff."
                        ),
                    ],
                    notes: "Play the riff on the A string and let the octave effect do the heavy lifting."
                ),
            ]
        ),
        Song(
            id: "under-the-bridge",
            title: "Under the Bridge",
            artist: "Red Hot Chili Peppers",
            album: "Blood Sugar Sex Magik",
            year: 1991,
            genre: .funkRock,
            tones: [
                Tone(
                    id: "utb-intro",
                    name: "Intro & Verse (Clean)",
                    amp: "Marshall JCM800 (low gain)",
                    character: .clean,
                    settings: AmpSettings(gain: 3, bass: 5.5, mid: 5, treble: 6, reverb: 2.5),
                    guitar: "Fender Stratocaster",
                    pickup: "Neck & middle positions",
                    pedals: [],
                    notes: "A Marshall run clean, not a Fender — that's why it has body. Thumb-over chord voicings with melody notes on top; switch pickups between intro (bridge-ish) and verse (neck warmth)."
                ),
            ]
        ),
        Song(
            id: "hotel-california",
            title: "Hotel California",
            artist: "Eagles",
            album: "Hotel California",
            year: 1976,
            genre: .rock,
            tones: [
                Tone(
                    id: "hotel-california-solo",
                    name: "Outro Solos",
                    amp: "Fender Tweed Deluxe",
                    character: .overdrive,
                    settings: AmpSettings(gain: 5.5, bass: 5, mid: 6, treble: 6),
                    guitar: "Gibson Les Paul",
                    pickup: "Bridge humbucker",
                    pedals: [
                        EffectPedal(
                            name: "Maestro Echoplex EP-3",
                            type: .delay,
                            controls: [
                                PedalControl(name: "Time", value: 2.5),
                                PedalControl(name: "Repeats", value: 2),
                                PedalControl(name: "Volume", value: 3),
                            ],
                            note: "Subtle slapback — warmth more than repeats."
                        ),
                    ],
                    notes: "Smooth, vocal overdrive from a small tweed amp on the edge. The harmonized outro is two guitars in thirds — learn both parts, record one, play the other."
                ),
            ]
        ),
        Song(
            id: "killing-in-the-name",
            title: "Killing in the Name",
            artist: "Rage Against the Machine",
            album: "Rage Against the Machine",
            year: 1992,
            genre: .funkRock,
            tones: [
                Tone(
                    id: "kitn-riff",
                    name: "Main Riff",
                    amp: "Marshall JCM800 2205 (50W)",
                    character: .highGain,
                    settings: AmpSettings(gain: 7.5, bass: 5.5, mid: 6, treble: 6, presence: 5.5),
                    guitar: "Custom Telecaster ('Arm the Homeless')",
                    pickup: "Bridge humbucker",
                    pedals: [
                        EffectPedal(
                            name: "DigiTech Whammy",
                            type: .octave,
                            controls: [],
                            note: "Solo — octave-up squeals and dives."
                        ),
                        EffectPedal(
                            name: "Dunlop Cry Baby",
                            type: .wah,
                            controls: [],
                            note: "Parked at fixed positions as a filter, plus full sweeps."
                        ),
                        EffectPedal(
                            name: "Boss DD-2",
                            type: .delay,
                            controls: [
                                PedalControl(name: "Time", value: 3),
                                PedalControl(name: "Feedback", value: 4),
                                PedalControl(name: "Level", value: 5),
                            ],
                            note: "Short digital repeats for the noise breaks."
                        ),
                    ],
                    notes: "Drop D. The riff tone is mid-forward Marshall grind — not scooped. Ghost-note funk strumming between power chords is what makes it groove."
                ),
            ]
        ),
    ]
}
