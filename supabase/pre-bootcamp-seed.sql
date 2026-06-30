-- Seed Pre-Bootcamp checklist tasks from "New Technician Pre Bootcamp Training List"
-- Run in Supabase -> SQL Editor AFTER supabase/checklist.sql
-- Safe to re-run: uses skill_code ON CONFLICT DO NOTHING

INSERT INTO public.skills (skill_code, section_id, category, name, sort_order)
SELECT v.code, sec.id, v.cat, v.name, v.ord
FROM (VALUES
  -- USAB Start
  ('pb1',  'pre_bootcamp', 'USAB START', 'Clock in/out — explain Air / Travel / Training difference', 1),
  ('pb2',  'pre_bootcamp', 'USAB START', 'How to view their schedule', 2),
  ('pb3',  'pre_bootcamp', 'USAB START', 'Where to find the drawings', 3),
  ('pb4',  'pre_bootcamp', 'USAB START', 'Where to find the task (on My Jobs and on the job itself)', 4),

  -- Drawings
  ('pb5',  'pre_bootcamp', 'DRAWINGS', 'Locate grilles and equipment on the drawings in relation to the site', 5),
  ('pb6',  'pre_bootcamp', 'DRAWINGS', 'Review the grille numbering systems', 6),
  ('pb7',  'pre_bootcamp', 'DRAWINGS', 'Review the schedule of equipment', 7),
  ('pb8',  'pre_bootcamp', 'DRAWINGS', 'Explain the difference between Supply Air, Return Air, and Exhaust Air grilles', 8),

  -- Test Instruments
  ('pb9',  'pre_bootcamp', 'TEST INSTRUMENTS', 'Familiar with the Evergreen Meter (on/off, store data)', 9),
  ('pb10', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Hood readings', 10),
  ('pb11', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Velocity readings', 11),
  ('pb12', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Static pressure readings', 12),
  ('pb13', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Read and adjust grilles; take and store meter readings; adjust dampers', 13),
  ('pb14', 'pre_bootcamp', 'TEST INSTRUMENTS', 'Hands-on with the tachometer and volt/amp meter', 14),

  -- Measurements
  ('pb15', 'pre_bootcamp', 'MEASUREMENTS', 'Measure grilles — make damper adjustments', 15),
  ('pb16', 'pre_bootcamp', 'MEASUREMENTS', 'Measure outside airflow', 16),
  ('pb17', 'pre_bootcamp', 'MEASUREMENTS', 'Measure static pressure', 17),
  ('pb18', 'pre_bootcamp', 'MEASUREMENTS', 'Measure voltage and amperage', 18),
  ('pb19', 'pre_bootcamp', 'MEASUREMENTS', 'Take unit/motor nameplate data', 19),
  ('pb20', 'pre_bootcamp', 'MEASUREMENTS', 'Measure building pressure', 20),
  ('pb21', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — measure a hood (if possible)', 21),
  ('pb22', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — locate Aks', 22),
  ('pb23', 'pre_bootcamp', 'MEASUREMENTS', 'Kitchen hood — complete the form', 23),

  -- USAB
  ('pb24', 'pre_bootcamp', 'USAB', 'Enter data on the Air / Inlet form', 24),
  ('pb25', 'pre_bootcamp', 'USAB', 'Enter data on the Traverse form (when setting O/A)', 25),
  ('pb26', 'pre_bootcamp', 'USAB', 'Enter data on the Air Apparatus form', 26),
  ('pb27', 'pre_bootcamp', 'USAB', 'Add a punch list/note and upload a picture', 27),
  ('pb28', 'pre_bootcamp', 'USAB', 'Add sheets', 28),
  ('pb29', 'pre_bootcamp', 'USAB', 'Change sheet statuses', 29),
  ('pb30', 'pre_bootcamp', 'USAB', 'Explain sheet hours', 30),
  ('pb31', 'pre_bootcamp', 'USAB', 'Review a punch list', 31),
  ('pb32', 'pre_bootcamp', 'USAB', 'Review a final report', 32)
) AS v(code, skey, cat, name, ord)
JOIN public.skill_sections sec ON sec.skey = v.skey
ON CONFLICT (skill_code) DO NOTHING;
