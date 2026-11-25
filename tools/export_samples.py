"""Copies backend/decks/*.json into game/scripts/sample_decks.gd as a GDScript constant.
Run from the repo root after editing samples:  python backend/build_samples.py && python tools/export_samples.py
"""
import glob, json
decks = [json.load(open(p, encoding="utf-8"))["deck"] for p in sorted(glob.glob("backend/decks/*.json"))]
body = json.dumps(decks, ensure_ascii=False, indent="\t")
out = ("class_name SampleDecks\nextends RefCounted\n"
       "## Built-in decks so judges can play instantly, even if the server is asleep.\n"
       "## Generated from backend/decks by tools/export_samples.py. Don't edit by hand.\n\n"
       "const DECKS := " + body + "\n")
open("game/scripts/sample_decks.gd", "w", encoding="utf-8").write(out)
print("wrote game/scripts/sample_decks.gd with", len(decks), "decks")
