#!/usr/bin/env bash
set -euo pipefail

echo "Setting up Kafka topics..."

# Create the main appointment events topic
docker exec health-audit-kafka kafka-topics --create --if-not-exists \
  --topic appt.events \
  --bootstrap-server localhost:19092 \
  --partitions 1 \
  --replication-factor 1

# Create additional topics for other event types
docker exec health-audit-kafka kafka-topics --create --if-not-exists \
  --topic lab.events \
  --bootstrap-server localhost:19092 \
  --partitions 1 \
  --replication-factor 1

docker exec health-audit-kafka kafka-topics --create --if-not-exists \
  --topic patient.events \
  --bootstrap-server localhost:19092 \
  --partitions 1 \
  --replication-factor 1

echo "Kafka topics created successfully!"

# List all topics to verify
echo "Current topics:"
docker exec health-audit-kafka kafka-topics --list --bootstrap-server localhost:19092