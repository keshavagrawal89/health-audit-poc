-- Audit ledger with hash chaining
CREATE TABLE IF NOT EXISTS audit.ledger (
  seq BIGSERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  row_pk TEXT NOT NULL,
  op TEXT NOT NULL,
  row_after JSONB NOT NULL,
  prev_hash TEXT,
  self_hash TEXT NOT NULL,
  at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit.hash_row(_prev TEXT, _tbl TEXT, _pk TEXT, _op TEXT, _row JSONB)
RETURNS TEXT AS $$
DECLARE
  payload TEXT := coalesce(_prev,'') || '|' || _tbl || '|' || _pk || '|' || _op || '|' || _row::text;
BEGIN
  RETURN encode(digest(payload, 'sha256'), 'hex');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit.write_ledger()
RETURNS TRIGGER AS $$
DECLARE
  _row JSONB;
  _pk  TEXT;
  _prev TEXT;
  _self TEXT;
BEGIN
  IF (TG_OP = 'INSERT') THEN _row := to_jsonb(NEW); _pk := NEW.id::text; END IF;
  IF (TG_OP = 'UPDATE') THEN _row := to_jsonb(NEW); _pk := NEW.id::text; END IF;
  IF (TG_OP = 'DELETE') THEN _row := to_jsonb(OLD); _pk := OLD.id::text; END IF;

  SELECT self_hash INTO _prev FROM audit.ledger
   WHERE table_name = TG_TABLE_NAME AND row_pk = _pk
   ORDER BY seq DESC LIMIT 1;

  _self := audit.hash_row(_prev, TG_TABLE_NAME, _pk, TG_OP, _row);

  INSERT INTO audit.ledger(table_name,row_pk,op,row_after,prev_hash,self_hash)
  VALUES (TG_TABLE_NAME, _pk, TG_OP, _row, _prev, _self);
  RETURN COALESCE(NEW, OLD);
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS audit_patients ON app.patients;
CREATE TRIGGER audit_patients  AFTER INSERT OR UPDATE OR DELETE ON app.patients
FOR EACH ROW EXECUTE FUNCTION audit.write_ledger();

DROP TRIGGER IF EXISTS audit_appointments ON app.appointments;
CREATE TRIGGER audit_appointments AFTER INSERT OR UPDATE OR DELETE ON app.appointments
FOR EACH ROW EXECUTE FUNCTION audit.write_ledger();

DROP TRIGGER IF EXISTS audit_lab_results ON app.lab_results;
CREATE TRIGGER audit_lab_results AFTER INSERT OR UPDATE OR DELETE ON app.lab_results
FOR EACH ROW EXECUTE FUNCTION audit.write_ledger();
