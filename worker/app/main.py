"""
Chat Worker Service - Processes chat requests from RabbitMQ queue
Instrumented with Datadog APM and Data Streams Monitoring
Uses Kombu for RabbitMQ (required for DSM support)
"""
import os
import json
import time
import logging
from typing import Dict, Any
from openai import OpenAI
from ddtrace import tracer, patch
# DSM checkpoints: Automatic via DD_DATA_STREAMS_ENABLED + Kombu
# from ddtrace.data_streams import set_checkpoint
from app.messaging import RabbitMQClient

# Enable Datadog APM tracing (kombu auto-instrumented for DSM)
patch(logging=True, kombu=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_PORT = int(os.getenv('RABBITMQ_PORT', '5672'))
RABBITMQ_USER = os.getenv('RABBITMQ_USER', 'guest')
RABBITMQ_PASS = os.getenv('RABBITMQ_PASS', 'guest')
REQUEST_QUEUE = os.getenv('REQUEST_QUEUE', 'chat_requests')
RESPONSE_QUEUE = os.getenv('RESPONSE_QUEUE', 'chat_responses')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-5-nano')

# Initialize OpenAI client
openai_client = OpenAI(api_key=OPENAI_API_KEY)


# Kombu client (global)
rabbitmq_client: RabbitMQClient = None

def init_rabbitmq():
    """Initialize RabbitMQ connection using Kombu"""
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
            logger.warning(f"Connection attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
            else:
                raise


def call_openai(prompt: str, conversation_history: list = None) -> Dict[str, Any]:
    """Call OpenAI API with tracing"""
    with tracer.trace("openai.chat.completions", service="openai-api") as span:
        span.set_tag("openai.model", OPENAI_MODEL)
        span.set_tag("openai.prompt_length", len(prompt))
        
        try:
            messages = conversation_history or []
            messages.append({"role": "user", "content": prompt})
            
            # Log what we're sending
            total_chars = sum(len(str(m.get('content', ''))) for m in messages)
            logger.info(f"Sending to OpenAI: {len(messages)} messages, {total_chars} total chars, last prompt: '{prompt[:100]}'")
            
            # GPT-5-nano only supports default temperature (1)
            # Other models like gpt-4o-mini support custom temperature
            create_params = {
                "model": OPENAI_MODEL,
                "messages": messages
            }
            
            # Only add temperature for models that support it (not gpt-5-nano)
            if "gpt-5" not in OPENAI_MODEL.lower():
                create_params["temperature"] = 0.7
                create_params["max_completion_tokens"] = 2000
            # Note: gpt-5-nano doesn't accept max_completion_tokens, uses model default
            
            response = openai_client.chat.completions.create(**create_params)
            
            response_text = response.choices[0].message.content or ""
            finish_reason = response.choices[0].finish_reason
            
            # Log token usage details
            prompt_tokens = response.usage.prompt_tokens if response.usage else 0
            completion_tokens = response.usage.completion_tokens if response.usage else 0
            total_tokens = response.usage.total_tokens if response.usage else 0
            
            logger.info(f"OpenAI response: finish_reason={finish_reason}, content_length={len(response_text)}, content_preview='{response_text[:100]}'")
            logger.info(f"Token usage: prompt={prompt_tokens}, completion={completion_tokens}, total={total_tokens}, max_requested={create_params.get('max_completion_tokens')}")
            
            if not response_text:
                logger.warning(f"Empty response from OpenAI! finish_reason={finish_reason}, model={OPENAI_MODEL}")
            
            span.set_tag("openai.response_length", len(response_text))
            span.set_tag("openai.finish_reason", finish_reason)
            span.set_tag("openai.usage.prompt_tokens", prompt_tokens)
            span.set_tag("openai.usage.completion_tokens", completion_tokens)
            span.set_tag("openai.usage.total_tokens", total_tokens)
            
            return {
                "response": response_text,
                "usage": {
                    "prompt_tokens": response.usage.prompt_tokens,
                    "completion_tokens": response.usage.completion_tokens,
                    "total_tokens": response.usage.total_tokens
                }
            }
        except Exception as e:
            logger.error(f"OpenAI API error: {e}")
            span.set_tag("error", True)
            span.set_tag("error.message", str(e))
            raise


def process_message(message_data: dict):
    """Process a single chat request message (DSM auto-instrumented by Kombu)"""
    request_id = message_data.get('request_id', 'unknown')
    
    with tracer.trace("worker.process_message", service="chat-worker", resource="process_chat_request") as span:
        span.set_tag("request.id", request_id)
        
        try:
            session_id = message_data.get('session_id')
            prompt = message_data.get('prompt')
            conversation_history = message_data.get('conversation_history', [])
            
            logger.info(f"Processing request {request_id} for session {session_id}")
            
            span.set_tag("session.id", session_id)
            span.set_tag("prompt.length", len(prompt))
            
            # Call OpenAI
            start_time = time.time()
            result = call_openai(prompt, conversation_history)
            processing_time = time.time() - start_time
            
            span.set_metric("processing.time", processing_time)
            logger.info(f"OpenAI responded in {processing_time:.2f}s")
            
            # Prepare response message
            response_message = {
                "request_id": request_id,
                "session_id": session_id,
                "prompt": prompt,  # Include original prompt for backend to save
                "response": result["response"],
                "usage": result["usage"],
                "processing_time": processing_time,
                "timestamp": time.time()
            }
            
            # Publish response to response queue (DSM auto-instrumented by Kombu)
            rabbitmq_client.publish(RESPONSE_QUEUE, response_message)
            
            logger.info(f"Response published for request {request_id}")
            span.set_tag("status", "success")
            
        except Exception as e:
            logger.error(f"Error processing message: {e}", exc_info=True)
            span.set_tag("error", True)
            span.set_tag("error.type", type(e).__name__)
            span.set_tag("error.message", str(e))
            raise  # Kombu will handle rejection/requeue


def main():
    """Main worker loop using Kombu for DSM support"""
    logger.info(f"Starting Chat Worker (model: {OPENAI_MODEL})")
    logger.info(f"Request queue: {REQUEST_QUEUE}, Response queue: {RESPONSE_QUEUE}")
    logger.info("Using Kombu for RabbitMQ (DSM enabled)")
    
    # Initialize RabbitMQ connection
    init_rabbitmq()
    
    # Start consuming (will block indefinitely and process messages)
    logger.info("Worker ready, waiting for messages...")
    try:
        rabbitmq_client.consume(REQUEST_QUEUE, process_message)
    except KeyboardInterrupt:
        logger.info("Worker shutting down...")
    finally:
        rabbitmq_client.close()
        logger.info("Worker stopped")


if __name__ == "__main__":
    main()

