import os, json, psycopg, sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from confluent_kafka import DeserializingConsumer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import StringDeserializer
from services.common.logging import get_logger

log = get_logger("consumer")

KAFKA_BOOT = os.getenv("KAFKA_BOOT", "localhost:19092")
PG_DSN = os.getenv("PG_DSN", "postgresql://app:app@localhost:15432/health")
GROUP = os.getenv("GROUP", "health-consumer")
TOPIC = os.getenv("TOPIC", "appt.events")
SR = os.getenv("SCHEMA_REGISTRY", "http://localhost:18081")

# Set up Avro deserializer
schema_path = os.path.join(os.path.dirname(__file__), "..", "..", "schemas", "appointment_created.avsc")
with open(schema_path) as f:
    schema_str = f.read()

src = SchemaRegistryClient({"url": SR})
avro_deserializer = AvroDeserializer(src, schema_str)

log.info("Connecting to Kafka at: %s", KAFKA_BOOT)
consumer = DeserializingConsumer({
    "bootstrap.servers": KAFKA_BOOT,
    "group.id": GROUP,
    "auto.offset.reset": "earliest",
    "key.deserializer": StringDeserializer('utf8'),
    "value.deserializer": avro_deserializer
})
consumer.subscribe([TOPIC])

with psycopg.connect(PG_DSN) as conn:
    while True:
        msg = consumer.poll(1.0)
        if not msg:
            continue
        if msg.error():
            log.error("Kafka error: %s", msg.error())
            continue

        # Message is already deserialized by AvroDeserializer
        evt = msg.value()

        event_id = evt["event_id"]
        checksum = str(hash(json.dumps(evt, sort_keys=True)))
        try:
            with conn.transaction():
                # Idempotency first
                cur = conn.execute("SELECT 1 FROM app.event_inbox WHERE event_id=%s", (event_id,))
                if cur.fetchone():
                    log.info("Duplicate event %s skipped", event_id)
                    consumer.commit(msg)
                    continue

                conn.execute(
                    "INSERT INTO app.event_inbox(event_id, checksum) VALUES (%s,%s)",
                    (event_id, checksum)
                )

                # Domain apply
                conn.execute(
                    "SELECT app.appointment_upsert(%s,%s,%s,%s,%s)",
                    (evt["appointment_id"], evt["patient_id"], evt["doctor_id"], evt["status"], evt["scheduled_at"])
                )
                log.info("Applied event %s appointment %s", event_id, evt["appointment_id"])
        except Exception as e:
            # TODO: send to DLQ/quarantine
            log.exception("Apply failed for %s: %s", event_id, e)
        finally:
            consumer.commit(msg)
