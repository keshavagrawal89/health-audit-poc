-- Temporal helpers and current-state view
CREATE OR REPLACE FUNCTION app.appointment_upsert(_id UUID, _patient UUID, _doctor UUID, _status TEXT, _scheduled_at TIMESTAMPTZ)
RETURNS VOID AS $$
DECLARE
  _current INT;
BEGIN
  SELECT version INTO _current FROM app.appointments
   WHERE id=_id AND valid_to IS NULL FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    UPDATE app.appointments SET valid_to = now()
      WHERE id=_id AND version=_current;
    INSERT INTO app.appointments(id,patient_id,doctor_id,status,scheduled_at,version,valid_from)
    VALUES (_id,_patient,_doctor,_status,_scheduled_at,_current+1, now());
  ELSE
    INSERT INTO app.appointments(id,patient_id,doctor_id,status,scheduled_at,version,valid_from)
    VALUES (_id,_patient,_doctor,_status,_scheduled_at,1, now());
  END IF;
END; $$ LANGUAGE plpgsql;

DROP MATERIALIZED VIEW IF EXISTS app.appointments_current;
CREATE MATERIALIZED VIEW app.appointments_current AS
  SELECT DISTINCT ON (id)
    id, patient_id, doctor_id, status, scheduled_at, version, valid_from
  FROM app.appointments
  WHERE valid_to IS NULL
  ORDER BY id, version DESC;
