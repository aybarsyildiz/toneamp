#!/usr/bin/env python3
"""Replace generic pedal names in SeedCatalog.json with specific commercial
models. Players on modelers (HeadRush, Helix, GT-series) pick blocks by the
model they emulate — "Analog Delay" is useless, "MXR Carbon Copy" is a target.
Idempotent: running twice changes nothing."""
import json
import sys

RENAMES = {
    "Analog Delay": "MXR Carbon Copy",
    "Digital Delay": "Boss DD-3 Digital Delay",
    "Delay": "Boss DD-3 Digital Delay",
    "Noise Gate": "Boss NS-2 Noise Suppressor",
    "Chorus": "Boss CE-2 Chorus",
    "Tremolo": "Boss TR-2 Tremolo",
    "Wah": "Dunlop Cry Baby GCB95",
    "Fuzz": "EHX Big Muff Pi",
    "Boost": "Ibanez TS9 Tube Screamer",
    "Octave": "EHX POG2",
    "Reverb": "Boss RV-6 Reverb",
    "Compressor": "MXR Dyna Comp",
    "Flanger": "MXR M117R Flanger",
    "Phaser": "MXR Phase 90",
    "Ibanez Tube Screamer": "Ibanez TS9 Tube Screamer",
    "MXR Chorus": "MXR M234 Analog Chorus",
}

path = sys.argv[1] if len(sys.argv) > 1 else "ToneAmp/SeedCatalog.json"
songs = json.load(open(path))
changed = 0
for song in songs:
    for tone in song["tones"]:
        for pedal in tone.get("pedals", []):
            if pedal["name"] in RENAMES:
                pedal["name"] = RENAMES[pedal["name"]]
                changed += 1
json.dump(songs, open(path, "w"), ensure_ascii=False, indent=1)
print(f"renamed {changed} pedal entries in {path}")
