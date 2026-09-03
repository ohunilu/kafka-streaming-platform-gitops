import json
import logging
import os
import signal
import time
import uuid
from datetime import datetime, timezone
from threading import Event

from confluent_kafka import Producer
from flask import Flask, jsonify
from prometheus_client import Counter, Histogram, generate_latest
from prometheus_client.exposition import CONTENT_TYPE_LATEST


logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

logger = logging.getLogger("customer-events-producer")


BOOTSTRAP_SERVERS = os.environ["KAFKA_BOOTSTRAP_SERVERS"]
API_KEY = os.environ["KAFKA_API_KEY"]
API_SECRET = os.environ["KAFKA_API_SECRET"]
TOPIC = os.getenv("KAFKA_TOPIC", "orders")


EVENTS_PRODUCED = Counter(
    "customer_events_produced_total",
    "Total number of customer events successfully produced",
)

EVENTS_FAILED = Counter(
    "customer_events_failed_total",
    "Total number of customer events that failed to produce",
)

PRODUCE_LATENCY = Histogram(
    "customer_events_produce_latency_seconds",
    "Kafka event production latency in seconds",
)

LAST_SUCCESS = 0.0


shutdown_event = Event()


app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "service": "customer-events-producer",
            "topic": TOPIC,
        }
    )


@app.route("/ready")
def ready():
    return jsonify({"status": "ready"})


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


def delivery_report(err, msg):
    global LAST_SUCCESS

    if err is not None:
        EVENTS_FAILED.inc()
        logger.error(
            "Kafka delivery failed: topic=%s error=%s",
            msg.topic(),
            err,
        )
        return

    EVENTS_PRODUCED.inc()
    LAST_SUCCESS = time.time()

    logger.info(
        "Event delivered: topic=%s partition=%s offset=%s",
        msg.topic(),
        msg.partition(),
        msg.offset(),
    )


def create_event():
    return {
        "event_id": str(uuid.uuid4()),
        "event_type": "order.created",
        "event_version": "1.0",
        "event_timestamp": datetime.now(timezone.utc).isoformat(),
        "order_id": f"ORD-{uuid.uuid4().hex[:8].upper()}",
        "customer_id": f"CUST-{uuid.uuid4().hex[:8].upper()}",
        "total_amount": round(25 + (uuid.uuid4().int % 97500) / 100, 2),
        "currency": "USD",
        "status": "created",
    }


def create_producer():
    configuration = {
        "bootstrap.servers": BOOTSTRAP_SERVERS,
        "security.protocol": "SASL_SSL",
        "sasl.mechanisms": "PLAIN",
        "sasl.username": API_KEY,
        "sasl.password": API_SECRET,
        "client.id": "customer-events-producer",
        "acks": "all",
        "enable.idempotence": True,
    }

    return Producer(configuration)


def produce_event(producer):
    event = create_event()
    payload = json.dumps(event).encode("utf-8")

    start = time.perf_counter()

    try:
        producer.produce(
            topic=TOPIC,
            key=event["customer_id"].encode("utf-8"),
            value=payload,
            callback=delivery_report,
        )

        producer.poll(0)

        PRODUCE_LATENCY.observe(time.perf_counter() - start)

        logger.info(
            "Event queued: event_id=%s order_id=%s customer_id=%s",
            event["event_id"],
            event["order_id"],
            event["customer_id"],
        )

    except Exception:
        EVENTS_FAILED.inc()
        logger.exception("Failed to produce event")


def signal_handler(signum, frame):
    logger.info("Shutdown signal received")
    shutdown_event.set()


def run_producer():
    producer = create_producer()

    logger.info(
        "Starting Kafka producer: topic=%s bootstrap_servers=%s",
        TOPIC,
        BOOTSTRAP_SERVERS,
    )

    try:
        while not shutdown_event.is_set():
            produce_event(producer)

            producer.poll(0)

            shutdown_event.wait(5)

    finally:
        logger.info("Flushing Kafka producer")

        producer.flush(timeout=10)

        logger.info("Kafka producer stopped")


def run_health_server():
    app.run(
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8080")),
        debug=False,
        use_reloader=False,
    )


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    from threading import Thread

    health_thread = Thread(
        target=run_health_server,
        daemon=True,
    )

    health_thread.start()

    run_producer()