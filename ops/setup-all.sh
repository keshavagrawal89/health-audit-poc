#!/usr/bin/env bash
set -euo pipefail

echo "=== Setting up Health Events Infrastructure ==="

echo "1. Running database migrations..."
bash ops/migrate.sh

echo "2. Setting up Kafka topics..."
bash ops/setup-kafka.sh

echo "3. Setting up Schema Registry schemas..."
# Register the appointment schema (schema must be a string, not object)
jq -n --rawfile schema schemas/appointment_created.avsc '{"schema": $schema}' > /tmp/appointment_schema.json
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @/tmp/appointment_schema.json \
  http://localhost:18081/subjects/appt.events-value/versions || echo "Schema registration failed, continuing..."
rm -f /tmp/appointment_schema.json

echo "=== Setup complete! ==="
echo ""
echo "You can now run:"
echo "  python3 services/consumer/consume_events.py    # Start consumer"
echo "  python3 services/producer/produce_events.py    # Produce test events"
echo "  python3 services/auditor/verify_audit_chain.py # Verify audit chain"
echo ""
echo "To reset everything for a fresh demo:"
echo "  bash ops/clean-slate.sh                        # Clean all data"