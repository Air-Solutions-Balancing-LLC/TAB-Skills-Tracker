-- Database-driven skills + sections for TAB Skills Tracker
-- Run in Supabase -> SQL Editor AFTER supabase/admin.sql (uses app_is_admin()).
-- Safe to re-run: tables use IF NOT EXISTS and the seed uses ON CONFLICT DO NOTHING.
--
-- Model:
--   skill_sections  = the experience-level groups shown in the questionnaire.
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
  avg_field  text,
  sort_order int,
  active     boolean NOT NULL DEFAULT true
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

-- ── Seed the 5 original sections ─────────────────────────────────────────────
INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order) VALUES
  ('safety',       'Safety + Core Values + Tools',     '🛡️', '#4A90D9', 'safety_avg',       1),
  ('basic',        'Basic Skills (0–3 months)',        '🟩', '#1D9E75', 'basic_avg',        2),
  ('intermediate', 'Intermediate Skills (4–12 months)','🟦', '#7aaedd', 'intermediate_avg', 3),
  ('advanced',     'Advanced Skills (13+ months)',     '🟨', '#9898c0', 'advanced_avg',     4),
  ('survey',       'TAB Survey Skills',                '🟪', '#AFA9EC', 'survey_avg',       5)
ON CONFLICT (skey) DO NOTHING;

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
  ('i1','intermediate','AIR BASICS','Economizers — Setting Unit Total Flow',1),
  ('i2','intermediate','AIR BASICS','Building Static Pressure',2),
  ('i3','intermediate','AIR BASICS','Balance Sidewall Grilles',3),
  ('i4','intermediate','TROUBLESHOOTING','Troubleshooting Low Airflow',4),
  ('i5','intermediate','UNIT TESTING','Air Handling Unit Component Identification',5),
  ('i6','intermediate','JOB MANAGEMENT','Job Readiness Report',6),
  ('i7','intermediate','JOB MANAGEMENT','Balance Basic Job Solo',7),
  ('i8','intermediate','TAB REPORTS','Writing Remarks',8),
  ('i9','intermediate','TAB REPORTS','USABalancer Proficiency',9),
  ('i10','intermediate','UNIT TESTING','Variable Frequency Drive',10),
  ('i11','intermediate','UNIT TESTING','Static Pressure Profile (Coil & Filter)',11),
  ('i12','intermediate','UNIT TESTING','DSS / Cabinet Unit Heater Balancing',12),
  ('i13','intermediate','JOB MANAGEMENT','Blueprint Reading / Mechanical Schedules',13),
  ('i14','intermediate','JOB MANAGEMENT','Mechanical Submittals Familiarity',14),
  ('i15','intermediate','JOB MANAGEMENT','Can Project Manage Their Jobs',15),
  ('i16','intermediate','JOB MANAGEMENT','Deadline Management',16),
  ('i17','intermediate','JOB MANAGEMENT','Shows Flexibility with Project Demands',17),
  ('i18','intermediate','JOB MANAGEMENT','Customer Service / Punch List Protocol',18),
  ('i19','intermediate','UNIT TESTING','Energy Recovery Units',19),
  ('i20','intermediate','UNIT TESTING','Motor Sheave Calculations',20),
  ('i21','intermediate','UNIT TESTING','Establishing Final SP Setpoint',21),
  ('i22','intermediate','UNIT TESTING','Total Unit CFM — VAV Systems',22),
  ('i23','intermediate','TAB REPORTS','Report Review Analysis',23),
  ('i24','intermediate','TERMINAL UNITS','VAVs',24),
  ('i25','intermediate','TERMINAL UNITS','Parallel Fan Powered Boxes',25),
  ('i26','intermediate','TROUBLESHOOTING','Troubleshooting VAVs',26),
  ('i27','intermediate','TERMINAL UNITS','Series Fan Powered Boxes',27),
  ('i28','intermediate','TERMINAL UNITS','Thermal Diffuser',28),
  ('i29','intermediate','UNIT TESTING','Airflow Monitor Calibration',29),
  ('i30','intermediate','UNIT TESTING','Fan Performance Curve Analysis',30),
  ('i31','intermediate','TROUBLESHOOTING','Fans and System Effect',31),
  ('i32','intermediate','TROUBLESHOOTING','Submittals',32),
  ('i33','intermediate','TROUBLESHOOTING','Occupant Comfort Issues',33),
  ('i34','intermediate','JOB MANAGEMENT','Specifications',34),
  ('i35','intermediate','JOB MANAGEMENT','Customer Service Skills',35),
  ('i36','intermediate','SPECIALTY TESTING','Air Changes per Hour',36),
  ('i37','intermediate','SPECIALTY TESTING','Fume Hoods',37),
  ('i38','intermediate','HYDRONICS','Balance Valves',38),
  ('i39','intermediate','HYDRONICS','Understands Hydronic Precautions',39),
  ('i40','intermediate','TERMINAL UNITS','HVAC Controls — Part 1',40),
  ('i41','intermediate','TERMINAL UNITS','Electronic Controls — Resource Access',41),
  ('i42','intermediate','TERMINAL UNITS','Pneumatic Controls — Resource Access',42),
  ('i43','intermediate','TERMINAL UNITS','HVAC Controls — Part 2',43),
  ('i44','intermediate','SPECIALTY TESTING','Setting O/A Temperature Method',44),
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
  ('a18','advanced','COMMISSIONING','Commissioning Basics',18),
  ('a19','advanced','SPECIALTY TESTING','Chilled Beams',19),
  ('a20','advanced','SPECIALTY TESTING','Duct Air Leakage Testing',20),
  ('a21','advanced','SPECIALTY TESTING','Sound Testing',21),
  ('a22','advanced','SPECIALTY TESTING','Vibration Testing',22),
  ('a23','advanced','SPECIALTY TESTING','Off-Season Testing',23),
  ('a24','advanced','SPECIALTY TESTING','Stairwell Pressurization Testing',24),
  ('a25','advanced','SPECIALTY TESTING','Temperature Differential Analysis / BTU Calculations',25),
  ('a26','advanced','SPECIALTY TESTING','Coil Water Carry Over',26),
  ('a27','advanced','TROUBLESHOOTING','Makeup Water / PRVs',27),
  ('a28','advanced','TROUBLESHOOTING','Piping Systems Comprehension',28),
  ('sv1','survey','UNIT TESTING','Ability to accurately measure Wire Size',1),
  ('sv2','survey','UNIT TESTING','Ability to calculate Carrier unit tonnage',2),
  ('sv3','survey','UNIT TESTING','Ability to accurately measure Gas and Condenser Pipe Size',3),
  ('sv4','survey','UNIT TESTING','Ability to identify Hot Gas Reheat Coils',4),
  ('sv5','survey','SURVEY PROJECTS','Can complete Surveys independently',5),
  ('sv6','survey','JOB MANAGEMENT','Job Approach: Work a job to estimated hours',6),
  ('sv7','survey','SURVEY REPORTS','USABalancer Proficiency — Survey reports',7),
  ('sv8','survey','SURVEY REPORTS','Report Review Analysis',8),
  ('sv9','survey','JOB MANAGEMENT','Customer Service: Punch List Protocol',9)
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
  FROM public.skill_sections s;

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
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.skill_sections WHERE id = p_section_id) THEN
    RAISE EXCEPTION 'Section not found';
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
