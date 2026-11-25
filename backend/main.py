"""QuestNotes backend.

Endpoints
  GET  /health           -> status + whether AI is on
  GET  /decks            -> list of built-in sample decks
  GET  /decks/{id}       -> one sample deck
  POST /generate         -> notes (pasted text or PDF/TXT upload) -> grounded deck
  POST /hint             -> wrong answer -> short hint from the notes

Run locally:  uvicorn main:app --reload
Without GEMINI_API_KEY it runs in mock mode (returns a sample deck), so the
Godot side can be built and tested without any key.
"""
import io
import json
import time
import uuid
from collections import defaultdict, deque
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware

import envfile  # noqa: F401  (loads backend/.env before llm reads the key)
import llm
from grounding import build_deck
from schema import Deck, HintRequest, HintResponse

MAX_CHARS = 30_000          # ~ 15-20 pages of notes
MIN_CHARS = 300             # too little text = nothing to quiz on
MAX_UPLOAD_BYTES = 8 * 1024 * 1024
GEN_LIMIT_PER_HOUR = 8      # per IP, protects the free Gemini quota

DECK_DIR = Path(__file__).parent / "decks"

app = FastAPI(title="QuestNotes API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],    # Godot web build runs on itch.io's domain
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

_hits: dict[str, deque] = defaultdict(deque)


def _rate_limit(ip: str) -> None:
    now = time.time()
    q = _hits[ip]
    while q and now - q[0] > 3600:
        q.popleft()
    if len(q) >= GEN_LIMIT_PER_HOUR:
        raise HTTPException(429, "Too many dungeons this hour. Try a sample deck or wait a bit.")
    q.append(now)


def _load_sample_decks() -> dict[str, dict]:
    decks = {}
    for p in sorted(DECK_DIR.glob("*.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        Deck.model_validate(data["deck"])  # fail fast if a sample is broken
        decks[data["deck"]["id"]] = data
    return decks


SAMPLES = _load_sample_decks()


def _extract_text(upload: UploadFile, raw: bytes) -> str:
    name = (upload.filename or "").lower()
    if name.endswith(".pdf") or upload.content_type == "application/pdf":
        from pypdf import PdfReader
        try:
            reader = PdfReader(io.BytesIO(raw))
            text = "\n".join((page.extract_text() or "") for page in reader.pages)
        except Exception:
            raise HTTPException(400, "Couldn't read that PDF. Try pasting the text instead.")
        if len(text.strip()) < MIN_CHARS:
            raise HTTPException(
                400, "This PDF looks scanned (no selectable text). Paste the text instead.")
        return text
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(400, "Upload a PDF or a .txt file.")


@app.get("/health")
def health():
    return {"ok": True, "ai": llm.enabled(), "model": llm.current_model() if llm.enabled() else None}


@app.get("/decks")
def list_decks():
    return [
        {"id": d["deck"]["id"], "title": d["deck"]["title"], "subject": d["deck"]["subject"],
         "concepts": len(d["deck"]["concepts"])}
        for d in SAMPLES.values()
    ]


@app.get("/decks/{deck_id}")
def get_deck(deck_id: str):
    if deck_id not in SAMPLES:
        raise HTTPException(404, "No such deck")
    return SAMPLES[deck_id]["deck"]


@app.post("/generate")
async def generate(
    request: Request,
    text: str = Form(default=""),
    file: UploadFile | None = File(default=None),
):
    if file is not None:
        raw = await file.read()
        if len(raw) > MAX_UPLOAD_BYTES:
            raise HTTPException(413, "File too big (max 8 MB).")
        notes = _extract_text(file, raw)
    else:
        notes = text

    notes = notes.strip()
    if len(notes) < MIN_CHARS:
        raise HTTPException(400, f"Need at least {MIN_CHARS} characters of notes.")
    truncated = len(notes) > MAX_CHARS
    notes = notes[:MAX_CHARS]

    if not llm.enabled():
        sample = SAMPLES.get("stacks-queues", next(iter(SAMPLES.values())))["deck"]
        return {**sample, "mock": True, "truncated": truncated}

    _rate_limit(request.client.host if request.client else "unknown")

    deck_id = uuid.uuid4().hex[:8]
    last_err = None
    for attempt in range(2):  # one retry if the model returns junk
        try:
            raw_deck = llm.generate_deck(notes)
            deck = build_deck(raw_deck, notes, deck_id, seed=attempt)
            if len(deck.concepts) >= 2:
                return {**deck.model_dump(), "mock": False, "truncated": truncated}
            last_err = "Not enough questions could be backed by your notes."
        except HTTPException:
            raise
        except llm.FriendlyError as e:
            raise HTTPException(502, str(e))
        except Exception as e:  # bad JSON from the model, network, etc.
            print(f"[generate] attempt {attempt + 1} failed: {type(e).__name__}: {str(e)[:300]}")
            last_err = f"AI error ({type(e).__name__}). Try again."
    raise HTTPException(502, last_err or "Generation failed. Try again.")


@app.post("/hint", response_model=HintResponse)
def hint(req: HintRequest):
    if not 0 <= req.picked_index < len(req.choices):
        raise HTTPException(400, "Bad picked_index")
    if llm.enabled():
        try:
            h = llm.generate_hint(req)
            if h:
                return HintResponse(hint=h, source_quote=req.source_quote, from_ai=True)
        except Exception:
            pass  # fall through to the offline hint
    return HintResponse(
        hint="Not quite. Check what your notes say here:",
        source_quote=req.source_quote,
        from_ai=False,
    )
