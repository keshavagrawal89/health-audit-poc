import os, time, json, sys, random
from pathlib import Path
from datetime import datetime, timedelta

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from confluent_kafka import SerializingProducer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import StringSerializer
from services.common.ids import new_event_id
from services.common.logging import get_logger

log = get_logger("producer")

BOOT = os.getenv("KAFKA_BOOT", "localhost:19092")
SR   = os.getenv("SCHEMA_REGISTRY", "http://localhost:18081")
TOPIC = os.getenv("TOPIC", "appt.events")

schema_path = os.path.join(os.path.dirname(__file__), "..", "..", "schemas", "appointment_created.avsc")
with open(schema_path) as f:
    schema_str = f.read()

src = SchemaRegistryClient({"url": SR})
serializer = AvroSerializer(src, schema_str)

producer = SerializingProducer({
    "bootstrap.servers": BOOT,
    "key.serializer": StringSerializer('utf8'),
    "value.serializer": serializer
})

# Demo patient and doctor IDs from demo data
DEMO_PATIENTS = [
    "019a0c25-0000-7000-8000-000000000001",  # Alice Johnson
    "019a0c25-0000-7000-8000-000000000002",  # Bob Williams
    "019a0c25-0000-7000-8000-000000000003",  # Carol Davis
]

DEMO_DOCTORS = [
    "019a0c25-0000-7000-8000-000000000101",  # Dr. Sarah Smith
    "019a0c25-0000-7000-8000-000000000102",  # Dr. Michael Jones
]

# Fixed appointment ID for demonstrating versioning
DEMO_APPOINTMENT_ID = "019a0c25-2000-7000-8000-000000000001"

base = datetime.utcnow()

# Create initial appointment (version 1)
evt = {
    "event_id": new_event_id(),
    "occurred_at": datetime.utcnow().isoformat() + "Z",
    "appointment_id": DEMO_APPOINTMENT_ID,
    "patient_id": random.choice(DEMO_PATIENTS),
    "doctor_id": random.choice(DEMO_DOCTORS),
    "status": "scheduled",
    "scheduled_at": (base + timedelta(days=1)).isoformat() + "Z",
}
producer.produce(TOPIC, key=evt["appointment_id"], value=evt)
producer.flush()
log.info("Created appointment %s (version 1)", evt["appointment_id"])
time.sleep(1)

# Update to completed (version 2)
evt["event_id"] = new_event_id()
evt["occurred_at"] = datetime.utcnow().isoformat() + "Z"
evt["status"] = "completed"
producer.produce(TOPIC, key=evt["appointment_id"], value=evt)
producer.flush()
log.info("Updated appointment %s to completed (version 2)", evt["appointment_id"])
time.sleep(1)

# Update scheduled time (version 3) - same status, different time
evt["event_id"] = new_event_id()
evt["occurred_at"] = datetime.utcnow().isoformat() + "Z"
evt["scheduled_at"] = (base + timedelta(days=1, hours=2)).isoformat() + "Z"  # Reschedule +2 hours
producer.produce(TOPIC, key=evt["appointment_id"], value=evt)
producer.flush()
log.info("Rescheduled appointment %s (version 3)", evt["appointment_id"])

# Create 2 more regular appointments
for i in range(2):
    evt = {
        "event_id": new_event_id(),
        "occurred_at": datetime.utcnow().isoformat() + "Z",
        "appointment_id": new_event_id(),
        "patient_id": random.choice(DEMO_PATIENTS),
        "doctor_id": random.choice(DEMO_DOCTORS),
        "status": "scheduled",
        "scheduled_at": (base + timedelta(days=i+2)).isoformat() + "Z",
    }
    producer.produce(TOPIC, key=evt["appointment_id"], value=evt)
    producer.flush()
    log.info("Created appointment %s", evt["appointment_id"])
    time.sleep(0.2)

log.info("Done. Check versioning with:")
log.info("SELECT id, status, version, valid_from, valid_to FROM app.appointments WHERE id = '%s' ORDER BY version;", DEMO_APPOINTMENT_ID)
