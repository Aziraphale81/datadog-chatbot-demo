"""
RabbitMQ messaging using Kombu for DSM support
"""
import json
import logging
import os
import threading
from typing import Dict, Callable, Optional
from kombu import Connection, Producer, Consumer, Queue, Exchange

logger = logging.getLogger(__name__)

class RabbitMQClient:
    """Kombu-based RabbitMQ client with DSM support"""
    
    def __init__(self, host: str, port: int, user: str, password: str):
        self.broker_url = f'amqp://{user}:{password}@{host}:{port}//'
        self.connection: Optional[Connection] = None
        self.producer: Optional[Producer] = None
        
    def connect(self):
        """Establish connection and create producer"""
        self.connection = Connection(self.broker_url)
        self.connection.connect()
        self.producer = Producer(self.connection)
        logger.info(f"Connected to RabbitMQ via Kombu at {self.broker_url}")
        
    def publish(self, queue_name: str, message: dict):
        """Publish message to queue (DSM auto-instrumented)"""
        if not self.producer:
            self.connect()
            
        # IMPORTANT: Pass dict directly, let Kombu serialize + inject DSM headers
        self.producer.publish(
            message,  # Dict, not json.dumps(message)
            routing_key=queue_name,
            declare=[Queue(queue_name, durable=True)],
            serializer='json',  # Let Kombu handle JSON serialization
        )
        logger.info(f"Published message to queue '{queue_name}': {message.get('request_id', 'unknown')}")
        
    def consume(self, queue_name: str, callback: Callable[[dict], None], timeout: float = None):
        """Consume messages from queue (DSM auto-instrumented)"""
        if not self.connection:
            self.connect()
            
        def on_message(body, message):
            """Process message and acknowledge (body is already deserialized by Kombu)"""
            try:
                # Kombu with accept=['json'] already deserializes JSON -> body is a dict
                callback(body)
                message.ack()
            except Exception as e:
                logger.error(f"Error processing message: {e}", exc_info=True)
                message.reject()
                
        queue = Queue(queue_name, durable=True)
        
        with Consumer(
            self.connection,
            queues=[queue],
            callbacks=[on_message],
            accept=['json']
        ):
            logger.info(f"Started consuming from queue '{queue_name}'...")
            
            if timeout:
                # Consume with timeout
                self.connection.drain_events(timeout=timeout)
            else:
                # Consume indefinitely
                while True:
                    try:
                        self.connection.drain_events(timeout=1)
                    except TimeoutError:
                        # Timeout is expected when no messages - continue waiting
                        continue
                    except Exception as e:
                        logger.error(f"Error in consumer: {e}", exc_info=True)
                        raise
                            
    def start_consumer_thread(self, queue_name: str, callback: Callable[[dict], None]):
        """Start background consumer thread"""
        def consumer_loop():
            try:
                self.consume(queue_name, callback)
            except Exception as e:
                logger.error(f"Consumer thread crashed: {e}", exc_info=True)
                
        thread = threading.Thread(target=consumer_loop, daemon=True)
        thread.start()
        logger.info(f"Background consumer thread started for queue '{queue_name}'")
        return thread
        
    def close(self):
        """Close connection"""
        if self.connection:
            self.connection.release()
            logger.info("Closed RabbitMQ connection")

