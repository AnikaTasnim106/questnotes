"""Gemini calls. Two jobs: notes -> deck, and wrong answer -> hint.

Model names change often, so we try a list and remember the first one that works.
Set GEMINI_MODEL to force a specific model.
"""
import os

from schema import LLMDeck, HintRequest

FALLBACK_MODELS = [
    "gemini-3.5-flash",
    "gemini-3.1-flash-lite",
    "gemini-3.8-flash",
    "gemini-3.5-flash-lite",
    "gemini-flash-latest",
    "gemini-2.5-flash",
]

_client = None
_working_model: str | None = None


class FriendlyError(Exception):
    """An error with a message that is safe and useful to show the player."""


def enabled() -> bool:
    return bool(os.getenv("GEMINI_API_KEY"))


def current_model() -> str | None:
    return _working_model or os.getenv("GEMINI_MODEL") or FALLBACK_MODELS[0]


def _candidates() -> list[str]:
    forced = os.getenv("GEMINI_MODEL")
    if forced:
        return [forced]
    if _working_model:
        return [_working_model] + [m for m in FALLBACK_MODELS if m != _working_model]
    return list(FALLBACK_MODELS)


def _get_client():
    global _client
    if _client is None:
        from google import genai
        _client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    return _client


def _model_missing(e: Exception) -> bool:
    code = getattr(e, "code", None)
    msg = str(e).lower()
    return code == 404 or "not found" in msg or "is not supported" in msg or "no longer available" in msg


def _friendly(e: Exception) -> FriendlyError:
    code = getattr(e, "code", None)
    msg = str(e)
    low = msg.lower()
    if "api key" in low or "api_key" in low or code in (401, 403):
        return FriendlyError("Gemini rejected the API key. Check the key in backend/.env (delete the file and run run_backend.bat again to re-enter it).")
    if code == 429 or "quota" in low or "resource_exhausted" in low:
        return FriendlyError("Gemini free quota is used up for now. Wait a minute and try again.")
    if code is not None and 500 <= int(code) < 600:
        return FriendlyError("Gemini is having trouble right now. Try again in a moment.")
    return FriendlyError(f"Gemini error {code}: {msg[:200]}")


def _call(contents: str, config) -> str:
    """Runs one request, trying fallback models if a model name is unknown."""
    global _working_model
    last: Exception | None = None
    for model in _candidates():
        try:
            resp = _get_client().models.generate_content(model=model, contents=contents, config=config)
            if _working_model != model:
                print(f"[llm] using model {model}")
            _working_model = model
            return resp.text or ""
        except Exception as e:  # google.genai.errors.APIError and friends
            print(f"[llm] {model} failed: {type(e).__name__}: {str(e)[:300]}")
            last = e
            if _model_missing(e):
                continue
            raise _friendly(e)
    raise FriendlyError("No Gemini model worked. Set GEMINI_MODEL in backend/.env to a current Flash model "
                        "from https://ai.google.dev/gemini-api/docs/models") from last


DECK_PROMPT = """You turn a student's study notes into a quiz dungeon.

Rules:
- Use ONLY facts stated in the notes below. Do not add outside knowledge.
- Pick {n_concepts} distinct key concepts from the notes.
- For each concept write {n_q} multiple-choice questions.
- Each question has exactly 4 choices, exactly one correct. Wrong choices must be
  plausible (common misconceptions), not silly.
- answer_index is the 0-based index of the correct choice.
- explanation: 1-2 short sentences, friendly, explains WHY the answer is right.
- source_quote: copy ONE sentence from the notes word-for-word that supports the
  answer. It must appear in the notes exactly. Never paraphrase it.
- difficulty: 1 = recall, 2 = understanding, 3 = application/tricky.
  Use a mix; at least one concept should be difficulty 3.
- Write in the same language as the notes.
- title: a short catchy dungeon name based on the topic. subject: the topic in 2-4 words.

NOTES:
\"\"\"
{notes}
\"\"\"
"""

HINT_PROMPT = """A student answered a quiz question wrong. Give a short hint (max 2 sentences)
that nudges them toward the right idea WITHOUT stating the correct choice outright.
Base the hint only on the source sentence. Be warm, not condescending.

Concept: {concept}
Question: {prompt}
They picked: {picked}
Source sentence from their notes: "{quote}"

Reply with the hint as plain text only: no markdown, no bullet points, no "Hint:" label."""


def generate_deck(notes: str, n_concepts: int = 5, n_q: int = 3) -> LLMDeck:
    from google.genai import types
    text = _call(
        DECK_PROMPT.format(notes=notes, n_concepts=n_concepts, n_q=n_q),
        types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=LLMDeck,
            temperature=0.4,
        ),
    )
    return LLMDeck.model_validate_json(text)


def clean_hint(text: str) -> str:
    """Strips markdown and labels; returns "" if what's left isn't a usable sentence."""
    import re
    t = re.sub(r"[*_#`>]+", "", text or "")
    t = re.sub(r"^\s*(hint|hints)\s*:?\s*", "", t.strip(), flags=re.I)
    t = re.sub(r"\s+", " ", t).strip()
    if len(t) < 15 or not re.search(r"[A-Za-z\u0980-\u09FF]{3}", t):
        return ""
    return t[:300]


def generate_hint(req: HintRequest) -> str:
    from google.genai import types
    # Newer Gemini models "think" before answering and those tokens count toward
    # max_output_tokens, so a small limit cut hints off mid-word. Leave room.
    text = _call(
        HINT_PROMPT.format(
            concept=req.concept,
            prompt=req.prompt,
            picked=req.choices[req.picked_index],
            quote=req.source_quote,
        ),
        types.GenerateContentConfig(temperature=0.5, max_output_tokens=2048),
    )
    return clean_hint(text)
