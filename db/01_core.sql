-- Core entities (using UUID v7 for time-ordered identifiers)
CREATE TABLE IF NOT EXISTS app.patients (
  id UUID PRIMARY KEY,
  phi_tokenized_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  dob DATE NOT NULL,
  meta JSONB DEFAULT '{}'::jsonb,
  created_on TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.appointments (
  id UUID NOT NULL,
  patient_id UUID NOT NULL REFERENCES app.patients(id),
  doctor_id UUID NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('scheduled','completed','canceled')),
  scheduled_at TIMESTAMPTZ NOT NULL,
  version INT NOT NULL,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_to   TIMESTAMPTZ,
  PRIMARY KEY (id, version)
);

CREATE TABLE IF NOT EXISTS app.lab_results (
  id UUID PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES app.patients(id),
  appointment_id UUID NOT NULL,
  kind TEXT NOT NULL,
  value JSONB NOT NULL,
  created_on TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.event_inbox (
  event_id TEXT PRIMARY KEY,
  checksum TEXT NOT NULL,
  applied_at TIMESTAMPTZ DEFAULT now()
);

-- Current-state MV (populated in 03_temporal)
