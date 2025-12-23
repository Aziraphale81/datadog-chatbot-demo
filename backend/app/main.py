import asyncio
import logging
import os
import uuid
from typing import Optional

from ddtrace import config, patch, tracer
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from openai import AsyncOpenAI
from pydantic import BaseModel
from psycopg import Connection
from psycopg_pool import ConnectionPool

# Enable common integrations
patch(psycopg=True, logging=True)

load_dotenv()

from pythonjsonlogger import jsonlogger

# JSON logging for automatic trace correlation
handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter('%(asctime)s %(levelname)s %(name)s %(message)s')
handler.setFormatter(formatter)

logging.basicConfig(
    level=logging.INFO,
    handlers=[handler],
)
logger = logging.getLogger("chat-backend")

DD_SERVICE = os.getenv("DD_SERVICE", "chat-backend")
DD_ENV = os.getenv("DD_ENV", "dev")
DD_VERSION = os.getenv("DD_VERSION", "0.1.0")
config.fastapi["service_name"] = DD_SERVICE
config.fastapi["request_span_name"] = "http.request"
config.http.trace_query_string = True

OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
POSTGRES_DSN = os.getenv(
    "POSTGRES_DSN", "postgresql://postgres:postgres@postgres:5432/postgres"
)
DBM_USER = os.getenv("DD_DB_USER", "datadog")
DBM_PASSWORD = os.getenv("DD_DB_PASSWORD", "datadog_password")

DUMMY_USER = {
    "id": os.getenv("DEMO_USER_ID", "demo-user-123"),
    "name": os.getenv("DEMO_USER_NAME", "Demo User"),
    "email": os.getenv("DEMO_USER_EMAIL", "demo@example.com"),
}

client = AsyncOpenAI(api_key=OPENAI_API_KEY)
pool: Optional[ConnectionPool] = None

app = FastAPI(title="Chatbot Backend", version=DD_VERSION)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    prompt: str
    user_id: Optional[str] = None
    user_name: Optional[str] = None
    user_email: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    message_id: str
    no_answer: bool


def ensure_db(pool: ConnectionPool) -> None:
    with pool.connection() as conn:  # type: Connection
        with conn.cursor() as cur:
            # Create chat_messages table
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS chat_messages (
                    id UUID PRIMARY KEY,
                    user_id TEXT,
                    user_name TEXT,
                    user_email TEXT,
                    prompt TEXT NOT NULL,
                    reply TEXT NOT NULL,
                    no_answer BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
                """
            )
            # Create datadog user for DBM (idempotent)
            try:
                cur.execute(
                    f"CREATE ROLE {DBM_USER} WITH LOGIN PASSWORD '{DBM_PASSWORD}';"
                )
            except Exception:
                # Role already exists, ignore
                conn.rollback()
            else:
                conn.commit()
            
            # Grant pg_monitor to datadog user
            cur.execute(f"GRANT pg_monitor TO {DBM_USER};")
        conn.commit()


async def init_db() -> None:
    global pool
    pool = ConnectionPool(conninfo=POSTGRES_DSN, min_size=1, max_size=5, timeout=10)
    await asyncio.to_thread(ensure_db, pool)
    logger.info("Database ready", extra={"dsn": POSTGRES_DSN})


@app.on_event("startup")
async def on_startup() -> None:
    if not OPENAI_API_KEY:
        logger.warning("OPENAI_API_KEY not set; OpenAI calls will fail")
    await init_db()


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": DD_SERVICE, "env": DD_ENV}


async def insert_message(
    message_id: str,
    prompt: str,
    reply: str,
    no_answer: bool,
    user: dict,
) -> None:
    assert pool is not None
    await asyncio.to_thread(
        _insert_message_blocking, pool, message_id, prompt, reply, no_answer, user
    )


def _insert_message_blocking(
    pool: ConnectionPool,
    message_id: str,
    prompt: str,
    reply: str,
    no_answer: bool,
    user: dict,
) -> None:
    with pool.connection() as conn:  # type: Connection
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO chat_messages (id, user_id, user_name, user_email, prompt, reply, no_answer)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    message_id,
                    user["id"],
                    user["name"],
                    user["email"],
                    prompt,
                    reply,
                    no_answer,
                ),
            )
        conn.commit()


async def call_openai(prompt: str) -> str:
    # Use Chat Completions API for broad compatibility across openai client versions
    response = await client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=200,
    )
    try:
        message = response.choices[0].message.content  # type: ignore[assignment]
    except Exception as exc:
        logger.exception("Unexpected OpenAI response shape", exc_info=exc)
        raise
    return message


@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    if not req.prompt or not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt is required")

    user = {
        "id": req.user_id or DUMMY_USER["id"],
        "name": req.user_name or DUMMY_USER["name"],
        "email": req.user_email or DUMMY_USER["email"],
    }

    span = tracer.current_span()
    if span:
        span.set_tag("chat.user_id", user["id"])
        span.set_tag("chat.user_email", user["email"])

    try:
        reply = await call_openai(req.prompt)
    except Exception as exc:
        logger.exception("OpenAI call failed")
        raise HTTPException(status_code=500, detail="LLM request failed") from exc

    no_answer = "i'm not sure" in reply.lower() or "cannot help" in reply.lower()
    message_id = str(uuid.uuid4())

    await insert_message(message_id, req.prompt, reply, no_answer, user)

    logger.info(
        "Handled chat request",
        extra={"user_id": user["id"], "no_answer": no_answer, "message_id": message_id},
    )

    return ChatResponse(reply=reply, message_id=message_id, no_answer=no_answer)


