#!/usr/bin/env bash
set -euo pipefail
psql postgresql://app:app@localhost:15432/health -f db/00_init.sql
psql postgresql://app:app@localhost:15432/health -f db/01_core.sql
psql postgresql://app:app@localhost:15432/health -f db/02_audit.sql
psql postgresql://app:app@localhost:15432/health -f db/03_temporal.sql
psql postgresql://app:app@localhost:15432/health -f db/99_demo_data.sql || true
