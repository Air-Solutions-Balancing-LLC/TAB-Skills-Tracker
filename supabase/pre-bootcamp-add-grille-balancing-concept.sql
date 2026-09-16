-- Add Pre-Bootcamp #14: Key Grille Balancing Concept (GRILLE BALANCING).
-- Safe to re-run: upserts pb35 and resets absolute sort_order for the list.

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
  ('pb35', 'pre_bootcamp', 'GRILLE BALANCING', 'Key Grille Balancing Concept', 14),
  ('pb33', 'pre_bootcamp', 'DUCT TRAVERSE', 'Perform a round duct traverse', 15),
  ('pb34', 'pre_bootcamp', 'DUCT TRAVERSE', 'Perform a rectangular duct traverse', 16),
  ('pb15', 'pre_bootcamp', 'MEASUREMENTS', 'Measure grilles — make damper adjustments', 17),
  ('pb16', 'pre_bootcamp', 'MEASUREMENTS', 'Measure outside airflow', 18),
  ('pb17', 'pre_bootcamp', 'MEASUREMENTS', 'Measure static pressure', 19),
  ('pb18', 'pre_bootcamp', 'MEASUREMENTS', 'Measure voltage and amperage', 20),
  ('pb19', 'pre_bootcamp', 'MEASUREMENTS', 'Take unit/motor nameplate data', 21),
  ('pb20', 'pre_bootcamp', 'MEASUREMENTS', 'Measure building pressure', 22),
  ('pb21', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — measure a hood (if possible)', 23),
  ('pb22', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — locate Aks', 24),
  ('pb23', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — complete the form', 25),
  ('pb24', 'pre_bootcamp', 'USAB', 'Enter data on the Air / Inlet form', 26),
  ('pb25', 'pre_bootcamp', 'USAB', 'Enter data on the Traverse form (when setting O/A)', 27),
  ('pb26', 'pre_bootcamp', 'USAB', 'Enter data on the Air Apparatus form', 28),
  ('pb27', 'pre_bootcamp', 'USAB', 'Add a punch list/note and upload a picture', 29),
  ('pb28', 'pre_bootcamp', 'USAB', 'Add sheets', 30),
  ('pb29', 'pre_bootcamp', 'USAB', 'Change sheet statuses', 31),
  ('pb30', 'pre_bootcamp', 'USAB', 'Explain sheet hours', 32),
  ('pb31', 'pre_bootcamp', 'USAB', 'Review a punch list', 33),
  ('pb32', 'pre_bootcamp', 'USAB', 'Review a final report', 34)
) AS v(code, skey, cat, name, ord)
JOIN public.skill_sections sec ON sec.skey = v.skey
ON CONFLICT (skill_code) DO UPDATE SET
  section_id = EXCLUDED.section_id,
  category   = EXCLUDED.category,
  name       = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  active     = true;

-- Verify: should return 34 active Pre-Bootcamp skills with pb35 at sort_order 14
-- SELECT sk.sort_order, sk.skill_code, sk.category, sk.name
-- FROM public.skills sk
-- JOIN public.skill_sections sec ON sec.id = sk.section_id
-- WHERE sec.skey = 'pre_bootcamp' AND sk.active
-- ORDER BY sk.sort_order;
