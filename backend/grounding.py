"""Responsible-AI layer: every question must be backed by the student's own notes.

The model returns a `source_quote` for each question. We check that quote
really exists in the uploaded text (exact or near-exact). Questions whose
quote can't be found are dropped, so the game never quizzes on something
the notes don't say.
"""
import random
import re
from difflib import SequenceMatcher

from schema import Deck, LLMDeck, Concept, Question

MATCH_THRESHOLD = 0.82


def _norm(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^\w\s\u0980-\u09FF]", " ", s)  # keep Bangla vowel signs
    return re.sub(r"\s+", " ", s).strip()


def _sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?।])\s+|\n+", text)
    return [_norm(p) for p in parts if len(p.strip()) > 8]


def quote_score(quote: str, norm_source: str, sentences: list[str]) -> float:
    q = _norm(quote)
    if len(q) < 8:
        return 0.0
    if q in norm_source:
        return 1.0
    best = 0.0
    for s in sentences:
        # Quick length filter keeps this fast on long notes.
        if abs(len(s) - len(q)) > max(len(q), 40):
            continue
        r = SequenceMatcher(None, q, s).ratio()
        if r > best:
            best = r
            if best >= 0.97:
                break
    return best


def _shuffle_choices(q: Question, rng: random.Random) -> Question:
    """Models love putting the right answer first. Shuffle so it isn't guessable."""
    order = list(range(4))
    rng.shuffle(order)
    q.choices = [q.choices[i] for i in order]
    q.answer_index = order.index(q.answer_index)
    return q


def build_deck(raw: LLMDeck, source_text: str, deck_id: str, seed: int = 0) -> Deck:
    rng = random.Random(seed)
    norm_source = _norm(source_text)
    sentences = _sentences(source_text)
    dropped = 0
    concepts: list[Concept] = []

    for ci, rc in enumerate(raw.concepts):
        questions: list[Question] = []
        for qi, rq in enumerate(rc.questions):
            # Structural sanity: 4 distinct choices, valid answer index.
            choices = [c.strip() for c in rq.choices][:4]
            if len(choices) != 4 or len(set(c.lower() for c in choices)) != 4:
                dropped += 1
                continue
            if not 0 <= rq.answer_index <= 3:
                dropped += 1
                continue
            score = quote_score(rq.source_quote, norm_source, sentences)
            if score < MATCH_THRESHOLD:
                dropped += 1
                continue
            q = Question(
                id=f"c{ci + 1}q{qi + 1}",
                prompt=rq.prompt.strip(),
                choices=choices,
                answer_index=rq.answer_index,
                explanation=rq.explanation.strip(),
                source_quote=rq.source_quote.strip(),
                grounded=True,
            )
            questions.append(_shuffle_choices(q, rng))
        if len(questions) >= 2:  # a room needs at least 2 enemies
            concepts.append(Concept(
                id=f"c{ci + 1}",
                name=rc.name.strip(),
                summary=rc.summary.strip(),
                difficulty=min(3, max(1, rc.difficulty)),
                questions=questions,
            ))
        else:
            dropped += len(questions)

    return Deck(
        id=deck_id,
        title=raw.title.strip(),
        subject=raw.subject.strip(),
        concepts=concepts,
        dropped_ungrounded=dropped,
    )
