-- REPLACE Pre-Bootcamp skills with Pre-Bootcamp_Skills_List_1.docx (33 items).
-- This is a full replacement of the pre_bootcamp section — not an addition.
-- Run in Supabase -> SQL Editor. Safe to re-run.
--
-- What it does:
--   1) Merges old pb2 progress into pb1 (if still present)
--   2) Upserts the 33 canonical skills (names/categories/order)
--   3) Deletes ANY other skills in the Pre-Bootcamp section
--   4) Strips removed skill codes from technicians.checklist_completed

-- 1) Merge pb2 progress into pb1 (keep the higher rating), then strip pb2 keys
UPDATE public.technicians t
SET checklist_completed = (
  CASE
    WHEN COALESCE(
      CASE WHEN jsonb_typeof(t.checklist_completed->'pb1') = 'number'
           THEN (t.checklist_completed->>'pb1')::int
           WHEN (t.checklist_completed->>'pb1') = 'true' THEN 2 ELSE 0 END, 0
    ) >= COALESCE(
      CASE WHEN jsonb_typeof(t.checklist_completed->'pb2') = 'number'
           THEN (t.checklist_completed->>'pb2')::int
           WHEN (t.checklist_completed->>'pb2') = 'true' THEN 2 ELSE 0 END, 0
    )
    THEN COALESCE(t.checklist_completed, '{}'::jsonb)
    ELSE COALESCE(t.checklist_completed, '{}'::jsonb)
         || jsonb_build_object(
              'pb1',
              CASE WHEN jsonb_typeof(t.checklist_completed->'pb2') = 'number'
                   THEN (t.checklist_completed->'pb2')
                   WHEN (t.checklist_completed->>'pb2') = 'true' THEN '2'::jsonb
                   ELSE '0'::jsonb END
            )
  END
) - 'pb2'
WHERE t.checklist_completed ? 'pb2';

-- Canonical skill codes for the replacement list
CREATE TEMP TABLE IF NOT EXISTS _pb_keep (code text PRIMARY KEY);
TRUNCATE _pb_keep;
INSERT INTO _pb_keep (code) VALUES
  ('pb1'),('pb3'),('pb4'),('pb5'),('pb6'),('pb7'),('pb8'),
  ('pb9'),('pb11'),('pb12'),('pb13'),('pb14'),('pb10'),
  ('pb33'),('pb34'),
  ('pb15'),('pb16'),('pb17'),('pb18'),('pb19'),('pb20'),
  ('pb21'),('pb22'),('pb23'),
  ('pb24'),('pb25'),('pb26'),('pb27'),('pb28'),('pb29'),
  ('pb30'),('pb31'),('pb32');

-- 2) Upsert the replacement list (reactivate if previously inactive)
INSERT INTO public.skills (skill_code, section_id, category, name, sort_order, active)
SELECT v.code, sec.id, v.cat, v.name, v.ord, true
FROM (VALUES
  ('pb1',  'pre_bootcamp', 'TIMES / SCHEDULE', 'Clock in/out / View Schedule', 1),
  ('pb3',  'pre_bootcamp', 'USAB START', 'Where to find the drawings', 2),
  ('pb4',  'pre_bootcamp', 'USAB START', 'Where to find the task (on My Jobs and on the job itself)', 3),
  ('pb5',  'pre_bootcamp', 'DRAWINGS', 'Locate grilles and equipment on the drawings in relation to the site', 4),
  ('pb6',  'pre_bootcamp', 'DRAWINGS', 'Review the grille numbering systems', 5),
  ('pb7',  'pre_bootcamp', 'DRAWINGS', 'Review the schedule of equipment', 6),
  ('pb8',  'pre_bootcamp', 'DRAWINGS', 'Explain the difference between Supply Air, Return Air, and Exhaust Air grilles', 7),
  ('pb9',  'pre_bootcamp', 'TEST INSTRUMENTS', 'Familiar with the Evergreen Meter (on/off, store readings)', 8),
  ('pb11', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Velocity readings', 9),
  ('pb12', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Static pressure readings', 10),
  ('pb13', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Read and adjust grilles; take and store meter readings; adjust dampers', 11),
  ('pb14', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Hands-on with the tachometer and volt/amp meter', 12),
  ('pb10', 'pre_bootcamp', 'GRILLE READINGS', 'Be able to take hood readings', 13),
  ('pb33', 'pre_bootcamp', 'DUCT TRAVERSE', 'Perform a round duct traverse', 14),
  ('pb34', 'pre_bootcamp', 'DUCT TRAVERSE', 'Perform a rectangular duct traverse', 15),
  ('pb15', 'pre_bootcamp', 'MEASUREMENTS', 'Measure grilles — make damper adjustments', 16),
  ('pb16', 'pre_bootcamp', 'MEASUREMENTS', 'Measure outside airflow', 17),
  ('pb17', 'pre_bootcamp', 'MEASUREMENTS', 'Measure static pressure', 18),
  ('pb18', 'pre_bootcamp', 'MEASUREMENTS', 'Measure voltage and amperage', 19),
  ('pb19', 'pre_bootcamp', 'MEASUREMENTS', 'Take unit/motor nameplate data', 20),
  ('pb20', 'pre_bootcamp', 'MEASUREMENTS', 'Measure building pressure', 21),
  ('pb21', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — measure a hood (if possible)', 22),
  ('pb22', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — locate Aks', 23),
  ('pb23', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — complete the form', 24),
  ('pb24', 'pre_bootcamp', 'USAB', 'Enter data on the Air / Inlet form', 25),
  ('pb25', 'pre_bootcamp', 'USAB', 'Enter data on the Traverse form (when setting O/A)', 26),
  ('pb26', 'pre_bootcamp', 'USAB', 'Enter data on the Air Apparatus form', 27),
  ('pb27', 'pre_bootcamp', 'USAB', 'Add a punch list/note and upload a picture', 28),
  ('pb28', 'pre_bootcamp', 'USAB', 'Add sheets', 29),
  ('pb29', 'pre_bootcamp', 'USAB', 'Change sheet statuses', 30),
  ('pb30', 'pre_bootcamp', 'USAB', 'Explain sheet hours', 31),
  ('pb31', 'pre_bootcamp', 'USAB', 'Review a punch list', 32),
  ('pb32', 'pre_bootcamp', 'USAB', 'Review a final report', 33)
) AS v(code, skey, cat, name, ord)
JOIN public.skill_sections sec ON sec.skey = v.skey
ON CONFLICT (skill_code) DO UPDATE SET
  section_id = EXCLUDED.section_id,
  category   = EXCLUDED.category,
  name       = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  active     = true;

-- 3) Strip removed Pre-Bootcamp keys from technician progress JSON
DO $$
DECLARE
  r record;
  v_code text;
  v_json jsonb;
BEGIN
  FOR r IN
    SELECT t.id, t.checklist_completed
    FROM public.technicians t
    WHERE t.checklist_completed IS NOT NULL
      AND t.checklist_completed <> '{}'::jsonb
  LOOP
    v_json := r.checklist_completed;
    FOR v_code IN
      SELECT key
      FROM jsonb_object_keys(r.checklist_completed) AS key
      WHERE key LIKE 'pb%'
        AND key NOT IN (SELECT code FROM _pb_keep)
    LOOP
      v_json := v_json - v_code;
    END LOOP;
    IF v_json IS DISTINCT FROM r.checklist_completed THEN
      UPDATE public.technicians
      SET checklist_completed = v_json
      WHERE id = r.id;
    END IF;
  END LOOP;
END $$;

-- 4) Delete every Pre-Bootcamp skill that is NOT on the replacement list
DELETE FROM public.skills sk
USING public.skill_sections sec
WHERE sk.section_id = sec.id
  AND sec.skey = 'pre_bootcamp'
  AND sk.skill_code NOT IN (SELECT code FROM _pb_keep);

DROP TABLE IF EXISTS _pb_keep;

-- Verify: should return exactly 33 active Pre-Bootcamp skills
-- SELECT sk.skill_code, sk.category, sk.name, sk.sort_order
-- FROM public.skills sk
-- JOIN public.skill_sections sec ON sec.id = sk.section_id
-- WHERE sec.skey = 'pre_bootcamp' AND sk.active
-- ORDER BY sk.sort_order;
