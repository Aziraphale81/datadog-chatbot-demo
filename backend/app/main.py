import asyncio
import json
import logging
import os
import threading
import time
import uuid
from typing import Optional

from ddtrace import config, patch, tracer
# DSM checkpoints: Automatic via DD_DATA_STREAMS_ENABLED
# from ddtrace.data_streams import set_checkpoint
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from openai import AsyncOpenAI
from pydantic import BaseModel
from psycopg import Connection
from psycopg_pool import ConnectionPool
from datetime import datetime
from typing import List, Dict
# Enable common integrations (kombu auto-patched for DSM)
patch(psycopg=True, logging=True, kombu=True)

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

# In-memory cache for responses (in production, use Redis)
response_cache: Dict[str, dict] = {}

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
    pool = ConnectionPool(conninfo=POSTGRES_DSN, min_size=1, max_size=5, timeout=10)
    await asyncio.to_thread(ensure_db, pool)
    logger.info("Database ready", extra={"dsn": POSTGRES_DSN})


def init_rabbitmq() -> None:
    """Initialize RabbitMQ connection using Kombu (for DSM support)"""
    global rabbitmq_client
    
    max_retries = 5
    retry_delay = 5
    
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


def consume_responses():
    """Background thread to consume response messages from RabbitMQ using Kombu"""
    def handle_response(response_data: dict):
        """Process response message (DSM auto-instrumented by Kombu)"""
        try:
            request_id = response_data.get('request_id')
            
            # Store response in cache
            response_cache[request_id] = response_data
            logger.info(f"Cached response for request {request_id}")
        except Exception as e:
            logger.error(f"Error processing response: {e}", exc_info=True)
    
    try:
        # Create separate client for consumer (separate connection)
        consumer_client = RabbitMQClient(
            host=RABBITMQ_HOST,
            port=RABBITMQ_PORT,
            user=RABBITMQ_USER,
            password=RABBITMQ_PASS
        )
        consumer_client.connect()
        logger.info("Starting background response consumer...")
        
        # This will block and consume messages
        consumer_client.consume(RESPONSE_QUEUE, handle_response)
    except Exception as e:
        logger.error(f"Response consumer error: {e}", exc_info=True)


@app.on_event("startup")
async def on_startup() -> None:
    if not OPENAI_API_KEY:
        logger.warning("OPENAI_API_KEY not set; OpenAI calls will fail")
    await init_db()
    
    # Initialize RabbitMQ
    await asyncio.to_thread(init_rabbitmq)
    
    # Start background consumer thread
    consumer_thread = threading.Thread(target=consume_responses, daemon=True)
    consumer_thread.start()
    logger.info("Background response consumer thread started")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": DD_SERVICE, "env": DD_ENV}


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


@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    """Submit a chat request to RabbitMQ queue and wait for worker response"""
    if not req.prompt or not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt is required")

    # Get or create session
    session_id = req.session_id
    if not session_id:
        # Create new session if not provided
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
        span.set_tag("chat.user_email", user["email"])
        span.set_tag("chat.session_id", session_id)

    request_id = str(uuid.uuid4())
    span.set_tag("chat.request_id", request_id)

    # Get conversation history for context
    # TEMPORARILY DISABLED - gpt-5-nano has limited context window
    conversation_history = []
    # try:
    #     messages = await get_session_messages(session_id)
    #     # Convert to OpenAI message format (last 2 messages for context)
    #     # Skip messages with empty replies to avoid confusing the model
    #     valid_messages = [msg for msg in messages if msg.reply and msg.reply.strip()]
    #     for msg in valid_messages[-2:]:
    #         conversation_history.append({"role": "user", "content": msg.prompt})
    #         conversation_history.append({"role": "assistant", "content": msg.reply})
    # except Exception as e:
    #     logger.warning(f"Could not fetch conversation history: {e}")

    # Publish message to RabbitMQ request queue (DSM auto-instrumented by Kombu)
    message_data = {
        "request_id": request_id,
        "session_id": session_id,
        "prompt": req.prompt,
        "conversation_history": conversation_history,
        "user": user
    }

    def _publish():
        rabbitmq_client.publish(REQUEST_QUEUE, message_data)

    await asyncio.to_thread(_publish)

    logger.info(
        "Published chat request to queue, waiting for worker response",
        extra={"user_id": user["id"], "request_id": request_id, "session_id": session_id},
    )

    # Wait for response from background consumer (up to 60 seconds)
    max_wait_seconds = 60
    poll_interval = 0.5  # Check every 500ms
    elapsed = 0
    
    while elapsed < max_wait_seconds:
        if request_id in response_cache:
            # Got the response!
            response_data = response_cache.pop(request_id)
            
            # Save to database
            message_id = str(uuid.uuid4())
            reply = response_data['response']
            no_answer = "i'm not sure" in reply.lower() or "cannot help" in reply.lower()
            
            await insert_message(message_id, session_id, req.prompt, reply, no_answer, user)
            
            logger.info(
                "Handled chat request via async queue",
                extra={"user_id": user["id"], "request_id": request_id, "message_id": message_id, "wait_time": elapsed},
            )
            
            return ChatResponse(
                reply=reply,
                message_id=message_id,
                session_id=session_id,
                no_answer=no_answer
            )
        
        await asyncio.sleep(poll_interval)
        elapsed += poll_interval
    
    # Timeout - worker didn't respond in time
    logger.error(f"Timeout waiting for worker response: {request_id}")
    raise HTTPException(status_code=504, detail="Worker timeout - please try again")


# ===== Session Management Endpoints =====

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


