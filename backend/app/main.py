import asyncio
import json
import json as _json
import logging
import os
import threading
import time
import uuid
from collections import deque
from typing import Optional

from ddtrace import config, patch, tracer
# DSM checkpoints: Automatic via DD_DATA_STREAMS_ENABLED
# from ddtrace.data_streams import set_checkpoint
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from openai import AsyncOpenAI
from pydantic import BaseModel
from psycopg import Connection
from psycopg_pool import ConnectionPool
from datetime import datetime
from typing import List, Dict
# Enable common integrations (kombu auto-patched for DSM)
patch(fastapi=True, psycopg=True, logging=True, kombu=True)

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

OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5-nano")
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

# RabbitMQ Configuration
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_PORT = int(os.getenv('RABBITMQ_PORT', '5672'))
RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'guest')
RABBITMQ_PASS = os.getenv('RABBITMQ_PASS', 'guest')
REQUEST_QUEUE = os.getenv('REQUEST_QUEUE', 'chat_requests')
RESPONSE_QUEUE = os.getenv('RESPONSE_QUEUE', 'chat_responses')

client = AsyncOpenAI(api_key=OPENAI_API_KEY)
pool: Optional[ConnectionPool] = None

# Import Kombu-based messaging client
from app.messaging import RabbitMQClient
rabbitmq_client: Optional[RabbitMQClient] = None

# In-memory streaming deque map for responses (keyed by request_id)
response_streams: Dict[str, deque] = {}

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
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    user_name: Optional[str] = None
    user_email: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    message_id: str
    session_id: str
    no_answer: bool


class Session(BaseModel):
    id: str
    title: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    message_count: int = 0


class Message(BaseModel):
    id: str
    session_id: str
    prompt: str
    reply: str
    created_at: datetime


class TitleRequest(BaseModel):
    session_id: str


def ensure_db(pool: ConnectionPool) -> None:
    with pool.connection() as conn:  # type: Connection
        with conn.cursor() as cur:
            # Create sessions table first (always)
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS sessions (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    title TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
                """
            )
            
            # Check if chat_messages table exists
            cur.execute(
                """
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = 'chat_messages'
                );
                """
            )
            table_exists = cur.fetchone()[0]
            
            if table_exists:
                # Check if it has session_id column
                cur.execute(
                    """
                    SELECT column_name FROM information_schema.columns 
                    WHERE table_name='chat_messages' AND column_name='session_id';
                    """
                )
                has_session_id = cur.fetchone() is not None
                
                if not has_session_id:
                    # Old schema exists, need to migrate
                    logger.info("Migrating chat_messages table to add session support...")
                    
                    # Add session_id column (nullable for now)
                    cur.execute(
                        """
                        ALTER TABLE chat_messages 
                        ADD COLUMN session_id UUID;
                        """
                    )
                    
                    # Create a default session for existing messages
                    cur.execute(
                        """
                        INSERT INTO sessions (id, title) 
                        VALUES ('00000000-0000-0000-0000-000000000000', 'Legacy Messages')
                        ON CONFLICT (id) DO NOTHING;
                        """
                    )
                    
                    # Update existing messages to reference the default session
                    cur.execute(
                        """
                        UPDATE chat_messages 
                        SET session_id = '00000000-0000-0000-0000-000000000000'
                        WHERE session_id IS NULL;
                        """
                    )
                    
                    # Now make session_id NOT NULL and add FK constraint
                    cur.execute(
                        """
                        ALTER TABLE chat_messages 
                        ALTER COLUMN session_id SET NOT NULL;
                        """
                    )
                    
                    cur.execute(
                        """
                        ALTER TABLE chat_messages 
                        ADD CONSTRAINT fk_session 
                        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;
                        """
                    )
                    
                    logger.info("Migration complete!")
            else:
                # Fresh install - create table with new schema
                cur.execute(
                    """
                    CREATE TABLE chat_messages (
                        id UUID PRIMARY KEY,
                        session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
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
            
            # Create index on session_id for faster lookups
            cur.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_messages_session_id 
                ON chat_messages(session_id);
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
    # Ensure first connection does not block forever (e.g. if Postgres is slow)
    dsn = POSTGRES_DSN + ("&" if "?" in POSTGRES_DSN else "?") + "connect_timeout=10"
    pool = ConnectionPool(conninfo=dsn, min_size=1, max_size=5, timeout=10)
    await asyncio.to_thread(ensure_db, pool)
    logger.info("Database ready", extra={"dsn": POSTGRES_DSN})


def init_rabbitmq() -> None:
    """Initialize RabbitMQ connection using Kombu (for DSM support)"""
    global rabbitmq_client
    
    max_retries = 30
    retry_delay = 10
    
    for attempt in range(max_retries):
        try:
            rabbitmq_client = RabbitMQClient(
                host=RABBITMQ_HOST,
                port=RABBITMQ_PORT,
                user=RABBITMQ_USER,
                password=RABBITMQ_PASS
            )
            rabbitmq_client.connect()
            logger.info(f"Connected to RabbitMQ via Kombu at {RABBITMQ_HOST}:{RABBITMQ_PORT}")
            return
        except Exception as e:
            logger.warning(f"RabbitMQ connection attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
            else:
                logger.error("Failed to connect to RabbitMQ after all retries")
                raise


def _init_rabbitmq_loop() -> None:
    """Run in a daemon thread: retry init_rabbitmq until success. Does not block startup."""
    global rabbitmq_client
    while True:
        try:
            init_rabbitmq()
            return
        except Exception as e:
            logger.warning(f"RabbitMQ publisher init failed (will retry in 10s): {e}")
            time.sleep(10)


def consume_responses():
    """Background thread to consume response messages from RabbitMQ. Reconnects on connection loss (e.g. RabbitMQ restart)."""
    def handle_response(response_data: dict):
        """Process response message (DSM auto-instrumented by Kombu)"""
        try:
            request_id = response_data.get('request_id')
            if request_id and request_id in response_streams:
                response_streams[request_id].append(response_data)
            # silently drop messages for unknown request_ids (stale responses after timeout)
        except Exception as e:
            logger.error(f"Error processing response: {e}", exc_info=True)

    while True:
        try:
            consumer_client = RabbitMQClient(
                host=RABBITMQ_HOST,
                port=RABBITMQ_PORT,
                user=RABBITMQ_USER,
                password=RABBITMQ_PASS
            )
            consumer_client.connect()
            logger.info("Starting background response consumer...")
            consumer_client.consume(RESPONSE_QUEUE, handle_response)
        except Exception as e:
            logger.error(f"Response consumer error (will reconnect in 10s): {e}", exc_info=True)
            time.sleep(10)


def _blocking_startup() -> None:
    """Run init_db, then start RabbitMQ publisher init in background and start consumer. Publisher init
    no longer blocks startup (so /chat can be used once RabbitMQ is ready, and consumer starts connecting).

    Database init is retried until success: after Docker Desktop / cluster restarts, CoreDNS or Postgres
    may not resolve immediately; a single failure used to abort the whole thread so RabbitMQ never started
    and /ready stayed 503 forever (frontend saw ECONNREFUSED to the backend Service)."""
    import asyncio
    global pool
    db_retry_delay = 5
    while True:
        try:
            asyncio.run(init_db())
            logger.info("Database init done")
            break
        except Exception as e:
            logger.warning(
                "Database init failed (will retry in %ss): %s",
                db_retry_delay,
                e,
                exc_info=False,
            )
            if pool is not None:
                try:
                    pool.close()
                except Exception:
                    pass
                pool = None
            time.sleep(db_retry_delay)

    try:
        # Publisher client: init in background thread so we don't block 5+ min if RabbitMQ is slow
        threading.Thread(target=_init_rabbitmq_loop, daemon=True).start()
        logger.info("RabbitMQ publisher init started in background")
        # Consumer runs here and has its own retry loop; can connect when RabbitMQ is ready
        consume_responses()
    except Exception as e:
        logger.error(f"Background startup failed after DB ready: {e}", exc_info=True)


@app.on_event("startup")
async def on_startup() -> None:
    """Start server quickly; run DB + RabbitMQ + consumer in a background thread so /health is available soon."""
    logger.info("Startup begun")
    if not OPENAI_API_KEY:
        logger.warning("OPENAI_API_KEY not set; OpenAI calls will fail")
    startup_thread = threading.Thread(target=_blocking_startup, daemon=True)
    startup_thread.start()
    logger.info("Background startup thread started")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": DD_SERVICE, "env": DD_ENV}


@app.get("/ready")
async def ready() -> dict:
    """Readiness: 200 only when DB pool and RabbitMQ publisher client are initialized. K8s uses this so traffic is not sent until chat can be served."""
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not ready")
    if rabbitmq_client is None:
        raise HTTPException(status_code=503, detail="Message queue not ready")
    return {"status": "ok", "service": DD_SERVICE, "ready": True}


async def insert_message(
    message_id: str,
    session_id: str,
    prompt: str,
    reply: str,
    no_answer: bool,
    user: dict,
) -> None:
    assert pool is not None
    await asyncio.to_thread(
        _insert_message_blocking, pool, message_id, session_id, prompt, reply, no_answer, user
    )


def _insert_message_blocking(
    pool: ConnectionPool,
    message_id: str,
    session_id: str,
    prompt: str,
    reply: str,
    no_answer: bool,
    user: dict,
) -> None:
    with pool.connection() as conn:  # type: Connection
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO chat_messages (id, session_id, user_id, user_name, user_email, prompt, reply, no_answer)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    message_id,
                    session_id,
                    user["id"],
                    user["name"],
                    user["email"],
                    prompt,
                    reply,
                    no_answer,
                ),
            )
            # Update session updated_at
            cur.execute(
                """
                UPDATE sessions SET updated_at = NOW() WHERE id = %s
                """,
                (session_id,)
            )
        conn.commit()


async def call_openai(prompt: str) -> str:
    # Use Chat Completions API for broad compatibility across openai client versions
    # Note: gpt-5-nano doesn't accept max_completion_tokens parameter
    response = await client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=[{"role": "user", "content": prompt}]
    )
    try:
        message = response.choices[0].message.content  # type: ignore[assignment]
    except Exception as exc:
        logger.exception("Unexpected OpenAI response shape", exc_info=exc)
        raise
    return message


async def _chat_stream(request_id: str, session_id: str, prompt: str, user: dict):
    """Async generator yielding SSE events for a chat request."""
    elapsed = 0.0
    max_wait = 45.0
    poll_interval = 0.05  # 50ms polling
    full_response_parts = []

    try:
        while elapsed < max_wait:
            q = response_streams.get(request_id)
            if q:
                while q:
                    msg = q.popleft()
                    msg_type = msg.get('type')

                    if msg_type == 'chunk':
                        content = msg.get('content', '')
                        full_response_parts.append(content)
                        yield f"data: {_json.dumps({'type': 'chunk', 'content': content})}\n\n"

                    elif msg_type == 'done':
                        reply = msg.get('response', ''.join(full_response_parts))
                        no_answer = "i'm not sure" in reply.lower() or "cannot help" in reply.lower()
                        message_id = str(uuid.uuid4())
                        try:
                            await insert_message(message_id, session_id, prompt, reply, no_answer, user)
                            logger.info("Handled chat request via streaming queue",
                                extra={"request_id": request_id, "session_id": session_id,
                                       "wait_time": elapsed, "user_id": user["id"]})
                        except Exception as db_err:
                            logger.error(f"DB insert failed: {db_err}")
                        response_streams.pop(request_id, None)
                        yield f"data: {_json.dumps({'type': 'done', 'message_id': message_id, 'session_id': session_id, 'reply': reply})}\n\n"
                        return

                    elif msg_type == 'error':
                        reply = msg.get('response', 'Something went wrong.')
                        no_answer = True
                        message_id = str(uuid.uuid4())
                        try:
                            await insert_message(message_id, session_id, prompt, reply, no_answer, user)
                        except Exception:
                            pass
                        response_streams.pop(request_id, None)
                        yield f"data: {_json.dumps({'type': 'done', 'message_id': message_id, 'session_id': session_id, 'reply': reply})}\n\n"
                        return

            await asyncio.sleep(poll_interval)
            elapsed += poll_interval

        # Timeout
        response_streams.pop(request_id, None)
        logger.error(f"Timeout waiting for worker response: {request_id}")
        yield f"data: {_json.dumps({'type': 'error', 'message': 'Worker timeout — please try again'})}\n\n"

    except Exception as e:
        response_streams.pop(request_id, None)
        logger.error(f"Stream error: {e}", exc_info=True)
        yield f"data: {_json.dumps({'type': 'error', 'message': 'Internal error'})}\n\n"


@app.post("/chat")
async def chat(req: ChatRequest) -> StreamingResponse:
    """Submit a chat request to RabbitMQ queue and stream the worker response via SSE."""
    if not req.prompt or not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt is required")

    session_id = req.session_id
    if session_id:
        # Verify session exists
        exists = await asyncio.to_thread(_session_exists_blocking, pool, session_id)
        if not exists:
            raise HTTPException(status_code=404, detail="Session not found")
    else:
        session_id = str(uuid.uuid4())
        await asyncio.to_thread(_create_session_blocking, pool, session_id)

    user = {
        "id": req.user_id or DUMMY_USER["id"],
        "name": req.user_name or DUMMY_USER["name"],
        "email": req.user_email or DUMMY_USER["email"],
    }

    span = tracer.current_span()
    if span:
        span.set_tag("chat.user_id", user["id"])
        span.set_tag("chat.session_id", session_id)

    # Build conversation history (last 3 turns = 6 messages)
    conversation_history = []
    try:
        msgs = await get_session_messages(session_id)
        valid = [m for m in msgs if m.reply and m.reply.strip()]
        for m in valid[-6:]:
            conversation_history.append({"role": "user", "content": m.prompt})
            conversation_history.append({"role": "assistant", "content": m.reply})
    except Exception as e:
        logger.warning(f"Could not fetch conversation history: {e}")

    request_id = str(uuid.uuid4())
    if span:
        span.set_tag("chat.request_id", request_id)

    # Wait for RabbitMQ to be ready
    wait_timeout = 90.0
    waited = 0.0
    while rabbitmq_client is None and waited < wait_timeout:
        await asyncio.sleep(0.5)
        waited += 0.5
    if rabbitmq_client is None:
        raise HTTPException(status_code=503, detail="Message queue is connecting. Please try again.")

    # Initialize stream buffer BEFORE publishing (avoid race with consumer)
    response_streams[request_id] = deque()

    message_data = {
        "request_id": request_id,
        "session_id": session_id,
        "prompt": req.prompt,
        "conversation_history": conversation_history,
        "user": user,
    }

    def _publish():
        rabbitmq_client.publish(REQUEST_QUEUE, message_data)
    await asyncio.to_thread(_publish)

    logger.info("Published chat request to queue (streaming)",
        extra={"request_id": request_id, "session_id": session_id, "user_id": user["id"]})

    return StreamingResponse(
        _chat_stream(request_id, session_id, req.prompt, user),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# ===== Session Management Endpoints =====

def _session_exists_blocking(pool: ConnectionPool, session_id: str) -> bool:
    """Return True if a session with the given id exists in the DB."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM sessions WHERE id = %s", (session_id,))
            return cur.fetchone() is not None


def _create_session_blocking(pool: ConnectionPool, session_id: str) -> None:
    """Create a new chat session"""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO sessions (id) VALUES (%s)
                """,
                (session_id,)
            )
        conn.commit()


@app.get("/sessions", response_model=List[Session])
async def list_sessions() -> List[Session]:
    """List all chat sessions with message counts"""
    assert pool is not None
    
    def _list_sessions() -> List[Session]:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.id, s.title, s.created_at, s.updated_at, COUNT(m.id) as message_count
                    FROM sessions s
                    LEFT JOIN chat_messages m ON s.id = m.session_id
                    GROUP BY s.id, s.title, s.created_at, s.updated_at
                    ORDER BY s.updated_at DESC
                    """
                )
                rows = cur.fetchall()
                return [
                    Session(
                        id=str(row[0]),
                        title=row[1],
                        created_at=row[2],
                        updated_at=row[3],
                        message_count=row[4]
                    )
                    for row in rows
                ]
    
    return await asyncio.to_thread(_list_sessions)


@app.post("/sessions", response_model=Session)
async def create_session() -> Session:
    """Create a new chat session"""
    assert pool is not None
    session_id = str(uuid.uuid4())
    
    def _create() -> Session:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO sessions (id) VALUES (%s)
                    RETURNING id, title, created_at, updated_at
                    """,
                    (session_id,)
                )
                row = cur.fetchone()
            conn.commit()
            return Session(
                id=str(row[0]),
                title=row[1],
                created_at=row[2],
                updated_at=row[3],
                message_count=0
            )
    
    return await asyncio.to_thread(_create)


@app.get("/sessions/{session_id}/messages", response_model=List[Message])
async def get_session_messages(session_id: str) -> List[Message]:
    """Get all messages for a session"""
    assert pool is not None
    
    def _get_messages() -> List[Message]:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, session_id, prompt, reply, created_at
                    FROM chat_messages
                    WHERE session_id = %s
                    ORDER BY created_at ASC
                    """,
                    (session_id,)
                )
                rows = cur.fetchall()
                return [
                    Message(
                        id=str(row[0]),
                        session_id=str(row[1]),
                        prompt=row[2],
                        reply=row[3],
                        created_at=row[4]
                    )
                    for row in rows
                ]
    
    return await asyncio.to_thread(_get_messages)


@app.post("/sessions/{session_id}/generate-title")
async def generate_session_title(session_id: str) -> dict:
    """Generate an AI title for a session based on its first messages"""
    assert pool is not None
    
    # Get first 2 messages
    def _get_first_messages() -> List[tuple]:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT prompt, reply FROM chat_messages
                    WHERE session_id = %s
                    ORDER BY created_at ASC
                    LIMIT 2
                    """,
                    (session_id,)
                )
                return cur.fetchall()
    
    messages = await asyncio.to_thread(_get_first_messages)
    
    if not messages:
        raise HTTPException(status_code=400, detail="No messages in session")
    
    # Build context for title generation
    conversation = "\n".join([f"User: {m[0]}\nAssistant: {m[1]}" for m in messages])
    
    # Ask OpenAI to generate a short title
    title_prompt = f"""Generate a short 4-5 word title for this conversation. Only respond with the title, nothing else.

Conversation:
{conversation}"""
    
    try:
        title = await call_openai(title_prompt)
        title = title.strip().strip('"').strip("'")  # Clean up quotes
        
        # Update session with title
        def _update_title() -> None:
            with pool.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        UPDATE sessions SET title = %s WHERE id = %s
                        """,
                        (title, session_id)
                    )
                conn.commit()
        
        await asyncio.to_thread(_update_title)
        
        return {"title": title, "session_id": session_id}
    
    except Exception as exc:
        logger.exception("Failed to generate title")
        raise HTTPException(status_code=500, detail="Title generation failed") from exc


@app.delete("/sessions/{session_id}")
async def delete_session(session_id: str) -> dict:
    """Delete a session and all its messages"""
    assert pool is not None
    
    def _delete() -> None:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                # Messages will be cascade deleted due to FK constraint
                cur.execute("DELETE FROM sessions WHERE id = %s", (session_id,))
            conn.commit()
    
    await asyncio.to_thread(_delete)
    return {"deleted": session_id}


@app.delete("/sessions")
async def delete_all_sessions() -> dict:
    """Delete all sessions and their messages"""
    assert pool is not None
    
    def _delete_all() -> int:
        with pool.connection() as conn:
            with conn.cursor() as cur:
                # Get count before deletion
                cur.execute("SELECT COUNT(*) FROM sessions")
                count = cur.fetchone()[0]
                # Messages will be cascade deleted due to FK constraint
                cur.execute("DELETE FROM sessions")
            conn.commit()
        return count
    
    deleted_count = await asyncio.to_thread(_delete_all)
    logger.info(f"Deleted all {deleted_count} sessions")
    return {"deleted_count": deleted_count, "message": f"Deleted {deleted_count} conversation(s)"}


# ============================================================================
# CHAOS ENGINEERING ENDPOINTS (for demo purposes)
# ============================================================================

from .chaos import (
    get_chaos_status,
    toggle_traffic,
    trigger_scenario
)

class TrafficRequest(BaseModel):
    enabled: bool
    level: str = "light"

class ScenarioRequest(BaseModel):
    scenario: str


@app.get("/chaos/status")
async def chaos_status() -> dict:
    """Get current chaos control panel status"""
    return await get_chaos_status()


@app.post("/chaos/traffic")
async def chaos_traffic(request: TrafficRequest) -> dict:
    """Enable/disable traffic generation"""
    return toggle_traffic(request.enabled, request.level)


@app.post("/chaos/scenario")
async def chaos_scenario(request: ScenarioRequest) -> dict:
    """Trigger a break-fix scenario"""
    return await trigger_scenario(request.scenario)
