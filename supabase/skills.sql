-- Database-driven skills + sections for TAB Skills Tracker
-- Run in Supabase -> SQL Editor AFTER supabase/admin.sql (uses app_is_admin()).
-- Safe to re-run: tables use IF NOT EXISTS and the seed uses ON CONFLICT DO NOTHING.
--
-- Model:
--   skill_sections  = the experience-level groups shown in the questionnaire.
--                     section_type is 'rated' (1–4 scoring) or 'checklist'
--                     (complete/incomplete, not scored). Checklist sections
--                     appear before Safety (Pre-Bootcamp).
--                     The original 5 carry an avg_field that maps to the legacy
--                     assessment columns (safety_avg, basic_avg, ...). New
--                     sections have avg_field = NULL; their scores are derived
--                     from the per-skill raw_scores snapshot on each assessment.
--   skills          = individual rated items. skill_code matches the keys stored
--                     in assessments.raw_scores so history keeps working.

-- ── Tables ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.skill_sections (
  id         bigserial PRIMARY KEY,
  skey       text NOT NULL UNIQUE,
  label      text NOT NULL,
  emoji      text,
  color      text,
  avg_field    text,
  sort_order   int,
  section_type text NOT NULL DEFAULT 'rated',
  active       boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.skills (
  id         bigserial PRIMARY KEY,
  skill_code text NOT NULL UNIQUE,
  section_id bigint NOT NULL REFERENCES public.skill_sections(id) ON DELETE CASCADE,
  category   text,
  name       text NOT NULL,
  sort_order int,
  active     boolean NOT NULL DEFAULT true
);
CREATE INDEX IF NOT EXISTS skills_section_idx ON public.skills (section_id);

-- ── Migrate existing databases (table may exist without newer columns) ────────
ALTER TABLE public.skill_sections
  ADD COLUMN IF NOT EXISTS section_type text NOT NULL DEFAULT 'rated';

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS checklist_completed jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.skill_sections SET section_type = 'rated' WHERE section_type IS NULL;

ALTER TABLE public.skill_sections
  ADD COLUMN IF NOT EXISTS checklist_mode text;

UPDATE public.skill_sections SET checklist_mode = 'rated' WHERE skey = 'pre_bootcamp';
-- Orientation tracking removed — keep row inactive if it still exists.
UPDATE public.skill_sections SET active = false, checklist_mode = 'checkbox' WHERE skey = 'orientation';
UPDATE public.skills SET active = false
 WHERE section_id IN (SELECT id FROM public.skill_sections WHERE skey = 'orientation');

-- ── Seed checklist + scored sections ─────────────────────────────────────────
INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode) VALUES
  ('pre_bootcamp', 'Pre-Bootcamp', '🎒', '#8B7355', NULL,           2, 'checklist', 'rated'),
  ('safety',       'Safety + Core Values + Tools',     '🛡️', '#4A90D9', 'safety_avg',       3, 'rated', NULL),
  ('safety_instruments', 'Safety and Instruments',     '🧰', '#0F6E56', NULL,                4, 'rated', NULL),
  ('basic',        'Basic Skills (0–3 months)',        '🟩', '#1D9E75', 'basic_avg',        5, 'rated', NULL),
  ('basic_solo_projects',   'TAB Basics Solo Projects',   '🏗️', '#0F6E56', NULL, 6, 'projects', NULL),
  ('basic_survey_projects', 'TAB Basics Survey Projects', '📐', '#1B3A6B', NULL, 7, 'projects', NULL),
  ('intermediate', 'Intermediate Skills (4 to 6 Months)','🟦', '#7aaedd', 'intermediate_avg', 8, 'rated', NULL),
  ('intermediate_7_12', 'Intermediate Skills (7 to 12 Months)','🔷', '#5B8FD9', NULL, 9, 'rated', NULL),
  ('advanced',     'Advanced Skills (13+ months)',     '🟨', '#9898c0', 'advanced_avg',    10, 'rated', NULL),
  ('special_testing_complex', 'Special Testing / Complex Projects', '🧪', '#6B5B95', NULL, 11, 'rated', NULL),
  ('survey',       'Survey Accounts',                  '🟪', '#AFA9EC', 'survey_avg',      12, 'rated', NULL),
  ('national_accounts', 'National Accounts',         '🏢', '#5B7C99', 'national_accounts_avg', 13, 'rated', NULL)
ON CONFLICT (skey) DO UPDATE
  SET section_type = COALESCE(EXCLUDED.section_type, public.skill_sections.section_type),
      checklist_mode = COALESCE(EXCLUDED.checklist_mode, public.skill_sections.checklist_mode),
      sort_order   = CASE WHEN public.skill_sections.skey IN ('pre_bootcamp','safety_instruments','basic_solo_projects','basic_survey_projects','intermediate_7_12','special_testing_complex')
                          THEN EXCLUDED.sort_order
                          ELSE public.skill_sections.sort_order END;

UPDATE public.skill_sections SET active = false WHERE skey = 'orientation';
UPDATE public.skills SET active = false
 WHERE section_id IN (SELECT id FROM public.skill_sections WHERE skey = 'orientation');

-- Ensure scored sections sit below the checklist sections on existing databases.
UPDATE public.skill_sections SET sort_order = 3, section_type = 'rated' WHERE skey = 'safety';
UPDATE public.skill_sections SET sort_order = 4, section_type = 'rated', label = 'Safety and Instruments', emoji = '🧰', color = '#0F6E56' WHERE skey = 'safety_instruments';
UPDATE public.skill_sections SET sort_order = 5, section_type = 'rated' WHERE skey = 'basic';
UPDATE public.skill_sections SET sort_order = 6, section_type = 'projects', label = 'TAB Basics Solo Projects', emoji = '🏗️', color = '#0F6E56' WHERE skey = 'basic_solo_projects';
UPDATE public.skill_sections SET sort_order = 7, section_type = 'projects', label = 'TAB Basics Survey Projects', emoji = '📐', color = '#1B3A6B' WHERE skey = 'basic_survey_projects';
UPDATE public.skill_sections SET sort_order = 8, section_type = 'rated', label = 'Intermediate Skills (4 to 6 Months)' WHERE skey = 'intermediate';
UPDATE public.skill_sections SET sort_order = 9, section_type = 'rated', label = 'Intermediate Skills (7 to 12 Months)', emoji = '🔷', color = '#5B8FD9' WHERE skey = 'intermediate_7_12';
UPDATE public.skill_sections SET sort_order = 10, section_type = 'rated' WHERE skey = 'advanced';
UPDATE public.skill_sections SET sort_order = 11, section_type = 'rated', label = 'Special Testing / Complex Projects', emoji = '🧪', color = '#6B5B95' WHERE skey = 'special_testing_complex';
UPDATE public.skill_sections SET sort_order = 12, section_type = 'rated', label = 'Survey Accounts' WHERE skey = 'survey';
UPDATE public.skill_sections SET sort_order = 13, section_type = 'rated' WHERE skey = 'national_accounts';

-- ── Seed skills (skill_code matches historical raw_scores keys) ──────────────
INSERT INTO public.skills (skill_code, section_id, category, name, sort_order)
SELECT v.code, sec.id, v.cat, v.name, v.ord
FROM (VALUES
  ('s1','safety','SAFETY','PPE Usage: Demonstrate proper daily usage and replacement of damaged or missing PPE.',1),
  ('s2','safety','SAFETY','Fall Protection: Explain and demonstrate ladder safety protocols and fall protection procedures.',2),
  ('s3','safety','SAFETY','Electrical Safety & LOTO: Apply electrical safety protocols including lockout/tagout procedures.',3),
  ('s4','safety','SAFETY','Tool Safety: Demonstrate proper tool safety and handling techniques including tool storage.',4),
  ('s5','safety','SAFETY','Vehicle Incident Reporting: Understand jobsite safety documentation and incident reporting procedures.',5),
  ('s6','safety','CORE VALUES','Integrity: Demonstrate integrity in daily work practices.',6),
  ('s7','safety','CORE VALUES','Responsiveness: Respond promptly and appropriately to the needs of others.',7),
  ('s8','safety','CORE VALUES','Teamwork: Collaborate effectively with others to achieve shared goals.',8),
  ('s9','safety','CORE VALUES','Wellness: Take proactive steps to maintain well-being and support a healthy workplace.',9),
  ('s10','safety','CORE VALUES','Always Improving: Look for ways to learn, grow, and improve performance.',10),
  ('s11','safety','CORE VALUES','All In: Show dedication and give your best effort in every task.',11),
  ('s12','safety','CORE VALUES','Accountability: Take ownership of actions and follow through on commitments.',12),
  ('s13','safety','TOOLS','100% Tooled-Up: Keep the Tool Report on USABalancer up to date to maintain full inventory.',13),
  ('b1','basic','TAB MATH','Area & Volume Calculations',1),
  ('b2','basic','TAB MATH','Basic Algebra',2),
  ('b3','basic','TAB MATH','CFM and RPM Relationships — Fan Law 1',3),
  ('b4','basic','TAB MATH','Flow Rate Calculations (CFM = A x V)',4),
  ('b5','basic','TAB MATH','Percentage Calculations',5),
  ('b6','basic','TAB MATH','Square/Cube Calculations — Fan Laws 2 & 3',6),
  ('b7','basic','TAB MATH','Unit Conversions (BTU, tonnage, CFM)',7),
  ('b8','basic','TAB MATH','Ratio & Proportion',8),
  ('b9','basic','INSTRUMENTS','Capture Hood Operation',9),
  ('b10','basic','INSTRUMENTS','Airfoil Usage & Traverse',10),
  ('b11','basic','INSTRUMENTS','Static Pressure Measurements (TSP & ESP)',11),
  ('b12','basic','INSTRUMENTS','Velocity Grid Operation',12),
  ('b13','basic','INSTRUMENTS','Rotating Vane Anemometer (RVA)',13),
  ('b14','basic','INSTRUMENTS','Temperature & Humidity Meters',14),
  ('b15','basic','INSTRUMENTS','Tachometer RPM Measurements',15),
  ('b16','basic','INSTRUMENTS','Strobe Scope RPM',16),
  ('b17','basic','INSTRUMENTS','Volt/Amp Meter',17),
  ('b18','basic','INSTRUMENTS','Temperature Data Logging',18),
  ('b19','basic','INSTRUMENTS','Instrument Management',19),
  ('b20','basic','INSTRUMENTS','Measurement Accuracy',20),
  ('b21','basic','AIR BASICS','Key Grille Balancing',21),
  ('b22','basic','AIR BASICS','Trial and Error Balancing',22),
  ('b23','basic','UNIT TESTING','Unit Data',23),
  ('b24','basic','UNIT TESTING','RPMs Actual and Predictive Measurement',24),
  ('b25','basic','UNIT TESTING','Volts & Amps Measurement',25),
  ('b26','basic','UNIT TESTING','Static Pressures Measurements',26),
  ('b27','basic','UNIT TESTING','Outside Airflows',27),
  ('b28','basic','UNIT TESTING','Duct Traverses',28),
  ('b29','basic','UNIT TESTING','Motor Starters',29),
  ('b30','basic','UNIT TESTING','Fan Testing',30),
  ('b31','basic','UNIT TESTING','Fan Law Review',31),
  ('b32','basic','UNIT TESTING','Coil Face Velocity',32),
  ('b33','basic','UNIT TESTING','Air Apps on RTUs and EF',33),
  ('b34','basic','UNIT TESTING','Air Apps on AHUs',34),
  ('b35','basic','AIR BALANCING','Ak''s',35),
  ('b36','basic','AIR BALANCING','Ratio Balancing',36),
  ('b37','basic','AIR BALANCING','Trial and Error Balancing',37),
  ('b38','basic','AIR BALANCING','KES Survey Projects',38),
  ('bsp1','basic_solo_projects','PROJECT','Project 1',1),
  ('bsp2','basic_solo_projects','PROJECT','Project 2',2),
  ('bsp3','basic_solo_projects','PROJECT','Project 3',3),
  ('bsp4','basic_solo_projects','PROJECT','Project 4',4),
  ('bsvp1','basic_survey_projects','PROJECT','Project 1',1),
  ('bsvp2','basic_survey_projects','PROJECT','Project 2',2),
  ('bsvp3','basic_survey_projects','PROJECT','Project 3',3),
  ('bsvp4','basic_survey_projects','PROJECT','Project 4',4),
  ('i4','intermediate','TROUBLESHOOTING','Troubleshooting Low Airflow',1),
  ('i6','intermediate','JOB MANAGEMENT','Job Readiness Report',2),
  ('i15','intermediate','JOB MANAGEMENT','Can Project Manage Their Jobs',3),
  ('i14','intermediate','JOB MANAGEMENT','Mechanical Submittals Familiarity',4),
  ('i16','intermediate','JOB MANAGEMENT','Deadline Management',5),
  ('i18','intermediate','JOB MANAGEMENT','Customer Service / Punch List Protocol',6),
  ('i17','intermediate','JOB MANAGEMENT','Shows Flexibility with Project Demands',7),
  ('i26','intermediate','TROUBLESHOOTING','Troubleshooting VAVs',8),
  ('i8','intermediate','TAB REPORTS','Writing Remarks',9),
  ('i23','intermediate','TAB REPORTS','Report Review Analysis',10),
  ('i24','intermediate','TERMINAL UNITS','VAVs',11),
  ('i25','intermediate','TERMINAL UNITS','Parallel Fan Powered Boxes',12),
  ('i10','intermediate_7_12','UNIT TESTING','Variable Frequency Drive',1),
  ('i11','intermediate_7_12','UNIT TESTING','Static Pressure Profile (Coil & Filter)',2),
  ('i12','intermediate_7_12','UNIT TESTING','DSS / Cabinet Unit Heater Balancing',3),
  ('i19','intermediate_7_12','UNIT TESTING','Energy Recovery Units',4),
  ('i20','intermediate_7_12','UNIT TESTING','Motor Sheave Calculations',5),
  ('i21','intermediate_7_12','UNIT TESTING','Establishing Final SP Setpoint',6),
  ('i22','intermediate_7_12','UNIT TESTING','Total Unit CFM — VAV Systems',7),
  ('i34','intermediate_7_12','JOB MANAGEMENT','Specifications',8),
  ('i35','intermediate_7_12','JOB MANAGEMENT','Customer Service Skills',9),
  ('i27','intermediate_7_12','TERMINAL UNITS','Series Fan Powered Boxes',10),
  ('i28','intermediate_7_12','TERMINAL UNITS','Thermal Diffuser',11),
  ('i29','intermediate_7_12','UNIT TESTING','Airflow Monitor Calibration',12),
  ('i30','intermediate_7_12','UNIT TESTING','Fan Performance Curve Analysis',13),
  ('i31','intermediate_7_12','TROUBLESHOOTING','Fans and System Effect',14),
  ('i32','intermediate_7_12','TROUBLESHOOTING','Submittals',15),
  ('i33','intermediate_7_12','TROUBLESHOOTING','Occupant Comfort Issues',16),
  ('i36','intermediate_7_12','SPECIALTY TESTING','Air Changes per Hour',17),
  ('i37','intermediate_7_12','SPECIALTY TESTING','Fume Hoods',18),
  ('i38','intermediate_7_12','HYDRONICS','Balance Valves',19),
  ('i39','intermediate_7_12','HYDRONICS','Understands Hydronic Precautions',20),
  ('i44','intermediate_7_12','SPECIALTY TESTING','Setting O/A Temperature Method',21),
  ('a1','advanced','HYDRONICS','Explain Hydronic Components',1),
  ('a2','advanced','HYDRONICS','Balance Chillers',2),
  ('a3','advanced','HYDRONICS','Balance Cooling Towers',3),
  ('a4','advanced','HYDRONICS','Balance Boilers',4),
  ('a5','advanced','HYDRONICS','Balance Condenser Water',5),
  ('a6','advanced','HYDRONICS','Pump Balancing',6),
  ('a7','advanced','HYDRONICS','Solving Humidity Issues',7),
  ('a8','advanced','HYDRONICS','Understanding NEBB Procedural Standards',8),
  ('a9','advanced','HYDRONICS','Stairwell Pressures',9),
  ('a10','advanced','HYDRONICS','Primary / Secondary Piping Balancing',10),
  ('a11','advanced','HYDRONICS','Coil Balancing',11),
  ('a12','advanced','HYDRONICS','Pump Operating Setpoint',12),
  ('a13','advanced','HYDRONICS','CV Balancing',13),
  ('a14','advanced','HYDRONICS','Heat Exchangers',14),
  ('a15','advanced','HYDRONICS','Ultrasonic Flow Meter',15),
  ('a16','advanced','TROUBLESHOOTING','Troubleshooting Hydronics',16),
  ('a17','advanced','COMMISSIONING','Sequence of Operations Familiarization',17),
  ('a19','advanced','SPECIALTY TESTING','Chilled Beams',19),
  ('a24','advanced','SPECIALTY TESTING','Stairwell Pressurization Testing',24),
  ('a26','advanced','SPECIALTY TESTING','Coil Water Carry Over',26),
  ('a27','advanced','TROUBLESHOOTING','Makeup Water / PRVs',27),
  ('a28','advanced','TROUBLESHOOTING','Piping Systems Comprehension',28),
  ('a20','special_testing_complex','SPECIALTY TESTING','Duct Air Leakage Testing',1),
  ('a21','special_testing_complex','SPECIALTY TESTING','Sound Testing',2),
  ('a22','special_testing_complex','SPECIALTY TESTING','Vibration Testing',3),
  ('a23','special_testing_complex','SPECIALTY TESTING','Off-Season Testing',4),
  ('a25','special_testing_complex','SPECIALTY TESTING','Temperature Differential Analysis / BTU Calculations',5),
  ('a18','special_testing_complex','COMMISSIONING','Understands Commissioning Basics / Sequence of Operations',6),
  ('sk264','special_testing_complex','COMPLEX PROJECTS','Handles all types of Complex Projects - Prisons, Hospitals, Labs, Military',7),
  ('sk265','special_testing_complex','LARGE PROJECT MANAGEMENT','Manage Large Projects, extending over several weeks to months.',8)
) AS v(code, skey, cat, name, ord)
JOIN public.skill_sections sec ON sec.skey = v.skey
ON CONFLICT (skill_code) DO NOTHING;

-- ── Public read: active sections with their active skills ─────────────────────
-- Returns a JSON array shaped like the app's QUESTIONNAIRE constant.
CREATE OR REPLACE FUNCTION public.app_skills()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'key', s.skey, 'section', s.label, 'emoji', s.emoji, 'color', s.color, 'avg_field', s.avg_field,
             'section_type', s.section_type,
             'checklist_mode', s.checklist_mode,
             'skills', COALESCE((
               SELECT jsonb_agg(jsonb_build_object('id', sk.skill_code, 'cat', sk.category, 'name', sk.name)
                                ORDER BY sk.sort_order, sk.id)
               FROM public.skills sk
               WHERE sk.section_id = s.id AND sk.active
             ), '[]'::jsonb)
           )
           ORDER BY s.sort_order, s.id
         ), '[]'::jsonb)
  FROM public.skill_sections s
  WHERE s.active;
$$;

-- ── Admin read: everything (incl. inactive) for the management screen ────────
CREATE OR REPLACE FUNCTION public.app_admin_list_skills()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'id', s.id, 'key', s.skey, 'section', s.label, 'emoji', s.emoji, 'color', s.color,
             'section_type', s.section_type,
             'checklist_mode', s.checklist_mode,
             'locked', (s.avg_field IS NOT NULL),
             'skills', COALESCE((
               SELECT jsonb_agg(jsonb_build_object('id', sk.id, 'code', sk.skill_code, 'cat', sk.category, 'name', sk.name)
                                ORDER BY sk.sort_order, sk.id)
               FROM public.skills sk
               WHERE sk.section_id = s.id
             ), '[]'::jsonb)
           )
           ORDER BY s.sort_order, s.id
         ), '[]'::jsonb) INTO v_result
  FROM public.skill_sections s
  WHERE s.skey IS DISTINCT FROM 'orientation';

  RETURN v_result;
END;
$$;

-- ── Admin: rename a section (the 5 sections are fixed; only the label/emoji
--    change). Scores stay tied to the section, so dashboards keep working. ─────
CREATE OR REPLACE FUNCTION public.app_admin_update_section(p_id bigint, p_label text DEFAULT NULL, p_emoji text DEFAULT NULL, p_color text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.skill_sections
  SET label = COALESCE(NULLIF(trim(p_label), ''), label),
      emoji = COALESCE(NULLIF(trim(p_emoji), ''), emoji),
      color = COALESCE(NULLIF(trim(p_color), ''), color)
  WHERE id = p_id;
END;
$$;

-- ── Admin: move/reorder skills (drag and drop) ───────────────────────────────
-- Sets every listed skill to p_section_id and renumbers them in array order.
CREATE OR REPLACE FUNCTION public.app_admin_reorder_skills(p_section_id bigint, p_ids bigint[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  i int;
  v_type text;
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT section_type INTO v_type FROM public.skill_sections WHERE id = p_section_id;
  IF v_type IS NULL THEN RAISE EXCEPTION 'Section not found'; END IF;

  IF EXISTS (
    SELECT 1
    FROM public.skills sk
    JOIN public.skill_sections sec ON sec.id = sk.section_id
    WHERE sk.id = ANY(p_ids) AND sec.section_type IS DISTINCT FROM v_type
  ) THEN
    RAISE EXCEPTION 'Cannot move tasks between checklist and rated sections';
  END IF;

  FOR i IN 1..COALESCE(array_length(p_ids, 1), 0) LOOP
    UPDATE public.skills SET section_id = p_section_id, sort_order = i WHERE id = p_ids[i];
  END LOOP;
END;
$$;

-- ── Admin: skill CRUD ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_add_skill(p_section_id bigint, p_name text, p_category text DEFAULT NULL)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ord int;
  v_id  bigint;
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_name IS NULL OR trim(p_name) = '' THEN RAISE EXCEPTION 'Skill name is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.skill_sections WHERE id = p_section_id) THEN
    RAISE EXCEPTION 'Section not found';
  END IF;

  SELECT COALESCE(max(sort_order), 0) + 1 INTO v_ord FROM public.skills WHERE section_id = p_section_id;

  INSERT INTO public.skills (skill_code, section_id, category, name, sort_order)
  VALUES ('tmp', p_section_id, NULLIF(trim(p_category), ''), trim(p_name), v_ord)
  RETURNING id INTO v_id;

  -- Generate a stable, unique skill_code from the new row id.
  UPDATE public.skills SET skill_code = 'sk' || v_id WHERE id = v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_update_skill(p_id bigint, p_name text DEFAULT NULL, p_category text DEFAULT NULL, p_section_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_section_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.skill_sections WHERE id = p_section_id) THEN
    RAISE EXCEPTION 'Section not found';
  END IF;
  UPDATE public.skills
  SET name       = COALESCE(NULLIF(trim(p_name), ''), name),
      category   = CASE WHEN p_category IS NULL THEN category ELSE NULLIF(trim(p_category), '') END,
      section_id = COALESCE(p_section_id, section_id)
  WHERE id = p_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_delete_skill(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.skills WHERE id = p_id;
END;
$$;

-- ── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.app_skills()                                  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_skills()                       TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_update_section(bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_reorder_skills(bigint, bigint[])     TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_add_skill(bigint, text, text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_update_skill(bigint, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_skill(bigint)                TO authenticated;
