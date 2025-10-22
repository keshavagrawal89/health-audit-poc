#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleaning Health Events Demo Data ==="

echo "1. Truncating application tables..."
psql postgresql://app:app@localhost:15432/health -c "
  TRUNCATE TABLE app.event_inbox CASCADE;
  TRUNCATE TABLE app.appointments CASCADE;
  TRUNCATE TABLE app.lab_results CASCADE;
  TRUNCATE TABLE app.patients CASCADE;
"

echo "2. Truncating audit ledger..."
psql postgresql://app:app@localhost:15432/health -c "
  TRUNCATE TABLE audit.ledger CASCADE;
"

echo "3. Refreshing materialized view..."
psql postgresql://app:app@localhost:15432/health -c "
  REFRESH MATERIALIZED VIEW app.appointments_current;
"

echo "4. Resetting Kafka consumer offsets..."
docker exec health-audit-kafka kafka-consumer-groups \
  --bootstrap-server localhost:19092 \
  --group health-consumer \
  --reset-offsets \
  --to-earliest \
  --topic appt.events \
  --execute 2>/dev/null || echo "  No consumer group found (this is normal for first run)"

echo "5. Deleting Kafka topic messages (recreating topic)..."
docker exec health-audit-kafka kafka-topics \
  --bootstrap-server localhost:19092 \
  --delete \
  --topic appt.events 2>/dev/null || echo "  Topic doesn't exist (this is normal)"

# Wait a moment for topic deletion
sleep 2

docker exec health-audit-kafka kafka-topics \
  --bootstrap-server localhost:19092 \
  --create \
  --topic appt.events \
  --partitions 1 \
  --replication-factor 1 \
  --if-not-exists

echo "6. Re-inserting demo data..."
bash ops/migrate.sh

echo "=== Clean slate complete! ==="
echo ""
echo "You can now run a fresh demo:"
echo "  python3 services/producer/produce_events.py    # Create events"
echo "  python3 services/consumer/consume_events.py    # Process events"
echo "  python3 services/auditor/verify_audit_chain.py # Verify audit"
echo ""
echo "Check results:"
echo "  psql postgresql://app:app@localhost:15432/health -c 'SELECT COUNT(*) FROM app.patients;'"
echo "  psql postgresql://app:app@localhost:15432/health -c 'SELECT COUNT(*) FROM audit.ledger;'"