"""RAG service — reads data/rag/*.md, finds relevant chunks,
and sends them to Ollama (primary/free/local), Groq (fallback), or Gemini for a grounded answer."""

import os
import re
import logging
import httpx
from typing import Optional
from pathlib import Path

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Ollama — free, local LLM (primary)
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2")

# Groq — free cloud fallback
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-lite")
RAG_DIR = Path(__file__).resolve().parent.parent / "data" / "rag"

# ---------------------------------------------------------------------------
# Document store — loaded once at import time
# ---------------------------------------------------------------------------

_chunks: list[dict] = []  # {"source": str, "heading": str, "body": str}


def _load_rag_documents() -> None:
    """Split each markdown file into chunks (one per ## heading)."""
    global _chunks
    _chunks.clear()

    if not RAG_DIR.exists():
        logger.warning("RAG directory %s does not exist — no documents loaded", RAG_DIR)
        return

    for md_file in sorted(RAG_DIR.glob("*.md")):
        text = md_file.read_text(encoding="utf-8")
        source = md_file.stem  # e.g. "facilities"
        # Split on ## headings
        sections = re.split(r"(?m)^## ", text)
        for sec in sections:
            sec = sec.strip()
            if not sec:
                continue
            # First line is the heading
            lines = sec.split("\n", 1)
            heading = lines[0].strip().lstrip("# ").strip()
            body = lines[1].strip() if len(lines) > 1 else ""
            _chunks.append({
                "source": source,
                "heading": heading,
                "body": body,
            })

    logger.info("Loaded %d RAG chunks from %s", len(_chunks), RAG_DIR)


# Load on import
_load_rag_documents()


def reload_rag_documents() -> None:
    """Reload RAG documents (call after data refresh)."""
    _load_rag_documents()


# ---------------------------------------------------------------------------
# Retrieval — keyword matching (fast, no embeddings needed)
# ---------------------------------------------------------------------------

def _score_chunk(chunk: dict, query_lower: str, keywords: list[str]) -> float:
    """Score a chunk against the user query — higher is better."""
    text = f"{chunk['heading']} {chunk['body']}".lower()
    score = 0.0

    # Exact substring of the query in heading
    if query_lower in chunk["heading"].lower():
        score += 5.0

    # Keyword hits
    for kw in keywords:
        if kw in text:
            score += 1.0
        if kw in chunk["heading"].lower():
            score += 2.0  # heading match is stronger

    return score


def retrieve_context(query: str, top_k: int = 15) -> str:
    """Return the most relevant RAG chunks as a single context string."""
    if not _chunks:
        return ""

    q_lower = query.lower()
    # Build keyword list — split query, remove stop-words
    stop = {"the", "a", "an", "is", "are", "in", "on", "at", "to", "for", "of",
            "and", "or", "what", "where", "how", "which", "can", "do", "does",
            "i", "me", "my", "you", "your", "it", "this", "that", "with", "from",
            "about", "near", "nearby", "closest", "nearest", "find", "show",
            "tell", "give", "list", "many", "much", "عن", "في", "من", "إلى", "ما",
            "هل", "أين", "كيف", "أي", "هذا", "هذه", "لي", "ال"}
    keywords = [w for w in re.findall(r"\w+", q_lower) if w not in stop and len(w) > 1]

    scored = [(chunk, _score_chunk(chunk, q_lower, keywords)) for chunk in _chunks]
    scored.sort(key=lambda x: x[1], reverse=True)

    # Take top_k with score > 0
    top = [c for c, s in scored[:top_k] if s > 0]

    if not top:
        # Fallback: return the statistics summary
        stats = [c for c in _chunks if c["source"] == "statistics"]
        top = stats[:3] if stats else _chunks[:5]

    parts = []
    for c in top:
        parts.append(f"### {c['heading']} ({c['source']})\n{c['body']}")

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# LLM calls — Groq (primary) → Gemini (fallback) → raw context (last resort)
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """You are **Aid NAV AI** — an intelligent crisis-response assistant for Palestine's West Bank.
You help first responders, health officials, and citizens find critical information about:
• Health facilities — hospitals, clinics, pharmacies, field hospitals
• Resources — ambulances, shelters, supply distribution points
• Active incidents — road closures, attacks, emergencies
• Geographic routing and distance information

Rules:
1. Answer in the language the user writes in (Arabic or English).
2. Be concise and actionable — bullet points for lists.
3. Include specific numbers (beds, distances, wait times) when available from the data.
4. If a photo description is provided, incorporate that context.
5. Never fabricate data; say "I don't have that information" if the context doesn't cover it.
6. When mentioning facilities, include their status and key details.
7. For follow-up questions, use conversation history for context.
8. Stay focused on crisis response — politely redirect off-topic questions.
9. Always base your answers on the Retrieved Situation Data provided below."""


def _build_messages(
    message: str,
    context: str,
    history: list | None,
    image_desc: str | None,
    language: str,
) -> list[dict]:
    """Build the chat messages list (OpenAI-compatible format used by Groq)."""
    system = SYSTEM_PROMPT
    if language == "ar":
        system += "\nRespond in Arabic (العربية)."

    msgs = [{"role": "system", "content": system}]

    if history:
        for h in history[-10:]:
            msgs.append({"role": h.role, "content": h.content})

    user_content = message
    if image_desc:
        user_content = f"[User attached a photo: {image_desc}]\n\n{message}"
    if context:
        user_content += f"\n\n--- Retrieved Situation Data ---\n{context}"

    msgs.append({"role": "user", "content": user_content})
    return msgs


async def _call_ollama(msgs: list[dict]) -> str | None:
    """Call local Ollama server. Returns answer text or None on failure."""
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                f"{OLLAMA_BASE_URL}/api/chat",
                json={
                    "model": OLLAMA_MODEL,
                    "messages": msgs,
                    "stream": False,
                    "options": {
                        "temperature": 0.3,
                        "num_predict": 800,
                    },
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return data.get("message", {}).get("content")
    except Exception as e:
        logger.warning("Ollama call failed: %s", e)
        return None


async def _call_groq(msgs: list[dict]) -> str | None:
    """Call Groq cloud API. Returns answer text or None on failure."""
    if not GROQ_API_KEY:
        return None
    try:
        from groq import Groq
        client = Groq(api_key=GROQ_API_KEY)
        resp = client.chat.completions.create(
            model=GROQ_MODEL,
            messages=msgs,
            temperature=0.3,
            max_tokens=800,
        )
        return resp.choices[0].message.content
    except Exception as e:
        logger.warning("Groq call failed: %s", e)
        return None


async def _call_gemini(msgs: list[dict]) -> str | None:
    """Call Google Gemini as fallback. Returns answer text or None."""
    if not GEMINI_API_KEY:
        return None
    try:
        from google import genai
        client = genai.Client(api_key=GEMINI_API_KEY)

        system_text = msgs[0]["content"] if msgs and msgs[0]["role"] == "system" else ""
        contents = []
        for m in msgs[1:]:
            role = "user" if m["role"] == "user" else "model"
            contents.append(
                genai.types.Content(role=role, parts=[genai.types.Part(text=m["content"])])
            )

        resp = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=contents,
            config=genai.types.GenerateContentConfig(
                system_instruction=system_text,
                temperature=0.3,
                max_output_tokens=800,
            ),
        )
        return resp.text
    except Exception as e:
        logger.warning("Gemini call failed: %s", e)
        return None


async def generate_reply(
    message: str,
    context: str,
    history: list | None = None,
    image_desc: str | None = None,
    language: str = "en",
) -> tuple[str, float]:
    """Generate a reply using cloud LLMs with RAG context.

    Tries Groq first (free, fast Llama 3.3 70B), then Gemini as fallback.
    Returns (reply_text, confidence).
    """
    msgs = _build_messages(message, context, history, image_desc, language)

    # 1. Try Ollama (primary — free, local, no API key needed)
    answer = await _call_ollama(msgs)
    if answer:
        confidence = 0.85 if len(context) > 200 else 0.7
        logger.info("Reply via Ollama (%s)", OLLAMA_MODEL)
        return answer, confidence

    # 2. Try Groq (fallback — free cloud)
    answer = await _call_groq(msgs)
    if answer:
        confidence = 0.9 if len(context) > 200 else 0.75
        logger.info("Reply via Groq (%s)", GROQ_MODEL)
        return answer, confidence

    # 3. Try Gemini (second fallback)
    answer = await _call_gemini(msgs)
    if answer:
        confidence = 0.85 if len(context) > 200 else 0.7
        logger.info("Reply via Gemini (%s)", GEMINI_MODEL)
        return answer, confidence

    # 4. Last resort — return raw context
    logger.warning("All LLM providers failed — returning raw context")
    if context:
        return f"Based on available data:\n\n{context}", 0.6
    return (
        "I can help you find facilities, resources, and incident information. "
        "Try asking about hospitals, shelters, or ambulances near you."
    ), 0.4
