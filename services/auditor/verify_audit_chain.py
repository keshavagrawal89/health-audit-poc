import psycopg, sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from services.common.logging import get_logger

log = get_logger("auditor")
PG_DSN = "postgresql://app:app@localhost:15432/health"

q = '''
SELECT seq, table_name, row_pk, op, prev_hash, self_hash,
       encode(digest(coalesce(prev_hash,'')||'|'||table_name||'|'||row_pk||'|'||op||'|'||row_after::text,'sha256'),'hex') AS recomputed
FROM audit.ledger ORDER BY seq
'''

with psycopg.connect(PG_DSN) as conn:
    rows = conn.execute(q).fetchall()
    ok = True
    for r in rows:
        seq, tbl, pk, op, prev_hash, self_hash, recomputed = r
        if self_hash != recomputed:
            ok = False
            log.error("Hash mismatch at seq=%s pk=%s table=%s", seq, pk, tbl)
    log.info("Audit chain valid: %s (rows=%d)", ok, len(rows))
