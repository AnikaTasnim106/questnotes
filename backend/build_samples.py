"""Turns hand-written sample decks (samples_src/) into game-ready decks (decks/).
Runs them through the same grounding check as AI decks, so a typo in a
source_quote fails loudly here instead of silently in the game.

    python build_samples.py
"""
import json
import sys
from pathlib import Path

from grounding import build_deck
from schema import LLMDeck

ROOT = Path(__file__).parent
ok = True
for src in sorted((ROOT / "samples_src").glob("*.json")):
    data = json.loads(src.read_text(encoding="utf-8"))
    raw = LLMDeck.model_validate(data["raw"])
    deck = build_deck(raw, data["source_text"], data["id"], seed=42)
    n_in = sum(len(c.questions) for c in raw.concepts)
    n_out = sum(len(c.questions) for c in deck.concepts)
    status = "OK " if deck.dropped_ungrounded == 0 else "BAD"
    if deck.dropped_ungrounded:
        ok = False
    print(f"{status} {data['id']}: {len(deck.concepts)} concepts, {n_out}/{n_in} questions kept")
    out = {"source_text": data["source_text"], "deck": deck.model_dump()}
    (ROOT / "decks" / f"{data['id']}.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

sys.exit(0 if ok else 1)
