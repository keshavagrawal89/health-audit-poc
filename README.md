# HIPAA-Grade Event-Driven Health Data Platform

A local, reproducible project demonstrating **temporal Postgres models**, **hash‑chained audit logs**, and **idempotent Kafka consumer** for healthcare events with complete infrastructure isolation.

## Stack
- **PostgreSQL 16** (Port: 15432) - Temporal tables, audit ledger, pgcrypto
- **Kafka + Schema Registry** (Ports: 19092, 18081) - Avro serialization, schema evolution
- **Redis** (Port: 16379) - Optional for DLQ/throttling
- **ClickHouse** (Ports: 18123, 19000) - Optional analytics sink
- **Python 3.12+** services with UUID v7 identifiers

## Jump on code/quick setup below or see here for a [more detailed blog](https://medium.com/@keshavagrawal/building-a-hipaa-grade-audit-logging-system-lessons-from-the-healthcare-trenches-d5a8bb691e3b).

## Quick Setup
```bash
# 1) Start infrastructure
docker compose up -d

# 2) Complete setup (DB + Kafka + Schemas)
bash ops/setup-all.sh

# 3) Start consumer (terminal A)
python3 services/consumer/consume_events.py

# 4) Produce test events (terminal B)
python3 services/producer/produce_events.py

# 5) Verify audit chain integrity
python3 services/auditor/verify_audit_chain.py
```

> Python dependencies are automatically managed:
```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

## Operational Commands

### Fresh Demo Setup
```bash
# Clean all data and start fresh
bash ops/clean-slate.sh

# Then run the quick setup above
```

### Individual Operations
```bash
# Database migrations and demo data
bash ops/migrate.sh

# Kafka topics setup
bash ops/setup-kafka.sh

# Complete system setup (combines above + schema registry)
bash ops/setup-all.sh

# Reset everything for fresh demo
bash ops/clean-slate.sh
```

### Verification Commands
```bash
# Check audit chain integrity
python3 services/auditor/verify_audit_chain.py

# View temporal versioning (shows all appointment versions)
psql postgresql://app:app@localhost:15432/health -c "
SELECT id, status, version, valid_from, valid_to
FROM app.appointments
ORDER BY id, version;"

# Check audit ledger
psql postgresql://app:app@localhost:15432/health -c "
SELECT table_name, row_pk, op, at
FROM audit.ledger
ORDER BY seq DESC LIMIT 10;"

# View current state (materialized view)
psql postgresql://app:app@localhost:15432/health -c "
SELECT * FROM app.appointments_current;"
```

## Directory Layout
```
health-events-internals/
├─ docker-compose.yml (isolated health-audit-* containers)
├─ db/ (SQL: core, audit, temporal schemas)
├─ schemas/ (Avro event definitions)
├─ services/
│  ├─ common/ (UUID v7 IDs, logging, crypto placeholders)
│  ├─ producer/ (Kafka + Avro event publishing)
│  ├─ consumer/ (Idempotent event processing)
│  └─ auditor/ (Hash chain verification)
├─ ops/ (setup-all.sh, setup-kafka.sh, migrate.sh)
└─ tests/
```

## Key Features
- **Hash-chained audit ledger** - Cryptographic tamper detection using SHA-256
- **Idempotent event processing** - Event inbox pattern prevents duplicate processing
- **Temporal data modeling** - Complete history with current-state materialized views
- **UUID v7 identifiers** - Time-ordered UUIDs for natural sorting and PostgreSQL compatibility
- **Infrastructure isolation** - Custom container names and non-standard ports
- **Schema evolution** - Avro-based type safety with backward compatibility
