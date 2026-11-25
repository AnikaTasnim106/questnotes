"""Data shapes shared by the API, the LLM call and the Godot client.

A Deck is what the game turns into a dungeon:
  deck -> concepts (one room each) -> questions (one enemy each).
The hardest concept becomes the boss room (decided in Godot).
"""
from pydantic import BaseModel, Field


class Question(BaseModel):
    id: str = ""
    prompt: str
    choices: list[str] = Field(min_length=4, max_length=4)
    answer_index: int = Field(ge=0, le=3)
    explanation: str
    # Exact sentence from the student's notes that supports the answer.
    source_quote: str
    # Filled in by grounding.py, never by the model.
    grounded: bool = False


class Concept(BaseModel):
    id: str = ""
    name: str
    summary: str
    difficulty: int = Field(ge=1, le=3)
    questions: list[Question]


class Deck(BaseModel):
    id: str = ""
    title: str
    subject: str
    concepts: list[Concept]
    # Questions dropped because their source quote wasn't found in the notes.
    dropped_ungrounded: int = 0


# --- What the model is asked to return (no server-filled fields) ---

class LLMQuestion(BaseModel):
    prompt: str
    choices: list[str]
    answer_index: int
    explanation: str
    source_quote: str


class LLMConcept(BaseModel):
    name: str
    summary: str
    difficulty: int
    questions: list[LLMQuestion]


class LLMDeck(BaseModel):
    title: str
    subject: str
    concepts: list[LLMConcept]


class HintRequest(BaseModel):
    concept: str
    prompt: str
    choices: list[str]
    answer_index: int
    picked_index: int
    source_quote: str


class HintResponse(BaseModel):
    hint: str
    source_quote: str
    from_ai: bool
