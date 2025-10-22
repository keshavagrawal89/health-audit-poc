-- Demo data (patients and doctors)
INSERT INTO app.patients(id, phi_tokenized_id, name, dob)
VALUES
  ('019a0c25-0000-7000-8000-000000000001', 'tok_alice_123', 'Alice Johnson', '1989-06-13'),
  ('019a0c25-0000-7000-8000-000000000002', 'tok_bob_456', 'Bob Williams', '1977-12-02'),
  ('019a0c25-0000-7000-8000-000000000003', 'tok_carol_789', 'Carol Davis', '1995-03-22')
ON CONFLICT DO NOTHING;

-- Demo doctors (stored as patients for simplicity in this POC)
INSERT INTO app.patients(id, phi_tokenized_id, name, dob)
VALUES
  ('019a0c25-0000-7000-8000-000000000101', 'doc_smith_001', 'Dr. Sarah Smith', '1975-09-15'),
  ('019a0c25-0000-7000-8000-000000000102', 'doc_jones_002', 'Dr. Michael Jones', '1982-11-08')
ON CONFLICT DO NOTHING;

-- Demo appointments to show temporal versioning
-- Create initial appointment (version 1)
SELECT app.appointment_upsert(
  '019a0c25-1000-7000-8000-000000000001',  -- appointment_id (fixed for demo)
  '019a0c25-0000-7000-8000-000000000001',  -- patient_id (Alice)
  '019a0c25-0000-7000-8000-000000000101',  -- doctor_id (Dr. Smith)
  'scheduled',                              -- status
  '2025-10-25T10:00:00Z'                   -- scheduled_at
);

-- Wait a moment then update the same appointment (version 2)
SELECT pg_sleep(0.1);
SELECT app.appointment_upsert(
  '019a0c25-1000-7000-8000-000000000001',  -- same appointment_id
  '019a0c25-0000-7000-8000-000000000001',  -- same patient_id
  '019a0c25-0000-7000-8000-000000000101',  -- same doctor_id
  'completed',                             -- status changed
  '2025-10-25T10:00:00Z'                   -- same time
);

-- Wait and update again (version 3) - change scheduled time
SELECT pg_sleep(0.1);
SELECT app.appointment_upsert(
  '019a0c25-1000-7000-8000-000000000001',  -- same appointment_id
  '019a0c25-0000-7000-8000-000000000001',  -- same patient_id
  '019a0c25-0000-7000-8000-000000000101',  -- same doctor_id
  'completed',                             -- same status but different time
  '2025-10-25T11:00:00Z'                   -- time changed (rescheduled)
);

-- Create another appointment with one update
SELECT app.appointment_upsert(
  '019a0c25-1000-7000-8000-000000000002',  -- appointment_id
  '019a0c25-0000-7000-8000-000000000002',  -- patient_id (Bob)
  '019a0c25-0000-7000-8000-000000000102',  -- doctor_id (Dr. Jones)
  'scheduled',                              -- status
  '2025-10-26T14:30:00Z'                   -- scheduled_at
);

SELECT pg_sleep(0.1);
SELECT app.appointment_upsert(
  '019a0c25-1000-7000-8000-000000000002',  -- same appointment_id
  '019a0c25-0000-7000-8000-000000000002',  -- same patient_id
  '019a0c25-0000-7000-8000-000000000102',  -- same doctor_id
  'canceled',                              -- status changed
  '2025-10-26T14:30:00Z'                   -- same time
);
