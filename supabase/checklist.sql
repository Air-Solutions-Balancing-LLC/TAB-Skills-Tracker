-- Orientation + Pre-Bootcamp checklist sections (not scored)
-- Run in Supabase -> SQL Editor on an EXISTING database.
-- Safe to re-run. Adds section_type, checklist sections, and checklist RPCs.
-- (skills.sql also includes these migrations for fresh installs.)

-- ── Section type: rated (1–5 skills) vs checklist (complete / incomplete) ─────
ALTER TABLE public.skill_sections
  ADD COLUMN IF NOT EXISTS section_type text NOT NULL DEFAULT 'rated';

-- ── Per-technician checklist state (skill_code -> true) ───────────────────────
ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS checklist_completed jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.skill_sections
  ADD COLUMN IF NOT EXISTS checklist_mode text;

UPDATE public.skill_sections SET checklist_mode = 'checkbox' WHERE skey = 'orientation';
UPDATE public.skill_sections SET checklist_mode = 'rated'    WHERE skey = 'pre_bootcamp';

-- ── Insert checklist sections before Safety ───────────────────────────────────
INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode) VALUES
  ('orientation',   'Orientation',   '📋', '#6B8CAE', NULL, 1, 'checklist', 'checkbox'),
  ('pre_bootcamp',  'Pre-Bootcamp',  '🎒', '#8B7355', NULL, 2, 'checklist', 'rated')
ON CONFLICT (skey) DO UPDATE
  SET label = EXCLUDED.label,
      emoji = EXCLUDED.emoji,
      color = EXCLUDED.color,
      avg_field = NULL,
      section_type = 'checklist',
      checklist_mode = EXCLUDED.checklist_mode,
      sort_order = EXCLUDED.sort_order,
      active = true;

-- Bump the 5 scored sections below the checklist sections.
UPDATE public.skill_sections SET sort_order = 3, section_type = 'rated' WHERE skey = 'safety';
UPDATE public.skill_sections SET sort_order = 4, section_type = 'rated' WHERE skey = 'basic';
UPDATE public.skill_sections SET sort_order = 5, section_type = 'rated' WHERE skey = 'intermediate';
UPDATE public.skill_sections SET sort_order = 6, section_type = 'rated' WHERE skey = 'advanced';
UPDATE public.skill_sections SET sort_order = 7, section_type = 'rated' WHERE skey = 'survey';

-- ── Public read: include section_type ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.app_skills();
CREATE OR REPLACE FUNCTION public.app_skills()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'key', s.skey, 'section', s.label, 'emoji', s.emoji, 'color', s.color,
             'avg_field', s.avg_field, 'section_type', s.section_type,
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

-- ── Admin read: include section_type ────────────────────────────────────────
DROP FUNCTION IF EXISTS public.app_admin_list_skills();
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

-- ── Reorder: only allow moves within the same section_type ──────────────────
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

-- ── Resolve tech_id from a session token ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_session_tech_id(p_token text)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT tech_id
  FROM public.sessions
  WHERE token = p_token
    AND expires_at > now()
    AND tech_id IS NOT NULL
  LIMIT 1;
$$;

-- ── Read checklist for a technician ─────────────────────────────────────────
-- Technicians: omit p_tech_id (uses their session).
-- PMs / admins: pass p_tech_id to view another technician's checklist.
CREATE OR REPLACE FUNCTION public.app_checklist_get(p_token text, p_tech_id bigint DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_session_tech bigint := app_session_tech_id(p_token);
  v_role         text;
  v_region       text;
  v_tech_id      bigint;
  v_completed    jsonb;
BEGIN
  IF p_tech_id IS NULL THEN
    v_tech_id := v_session_tech;
  ELSE
    SELECT role, region INTO v_role, v_region
    FROM public.sessions
    WHERE token = p_token AND expires_at > now()
    LIMIT 1;

    IF v_role = 'pm' OR app_is_admin() THEN
      v_tech_id := p_tech_id;
    ELSIF v_session_tech = p_tech_id THEN
      v_tech_id := p_tech_id;
    ELSE
      RAISE EXCEPTION 'Not authorized';
    END IF;
  END IF;

  IF v_tech_id IS NULL THEN
    RETURN '{}'::jsonb;
  END IF;

  SELECT COALESCE(checklist_completed, '{}'::jsonb) INTO v_completed
  FROM public.technicians
  WHERE id = v_tech_id AND deleted_at IS NULL;

  RETURN COALESCE(v_completed, '{}'::jsonb);
END;
$$;

-- ── Toggle one checklist task (technician marks their own tasks) ────────────
CREATE OR REPLACE FUNCTION public.app_checklist_toggle(p_token text, p_skill_code text, p_done boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id   bigint := app_session_tech_id(p_token);
  v_code      text := NULLIF(trim(p_skill_code), '');
  v_completed jsonb;
BEGIN
  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'Task code is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.skills sk
    JOIN public.skill_sections sec ON sec.id = sk.section_id
    WHERE sk.skill_code = v_code
      AND sk.active
      AND sec.active
      AND sec.section_type = 'checklist'
      AND COALESCE(sec.checklist_mode, 'checkbox') = 'checkbox'
  ) THEN
    RAISE EXCEPTION 'Invalid checklist task';
  END IF;

  IF p_done THEN
    UPDATE public.technicians
    SET checklist_completed = COALESCE(checklist_completed, '{}'::jsonb) || jsonb_build_object(v_code, true)
    WHERE id = v_tech_id AND deleted_at IS NULL
    RETURNING checklist_completed INTO v_completed;
  ELSE
    UPDATE public.technicians
    SET checklist_completed = COALESCE(checklist_completed, '{}'::jsonb) - v_code
    WHERE id = v_tech_id AND deleted_at IS NULL
    RETURNING checklist_completed INTO v_completed;
  END IF;

  RETURN COALESCE(v_completed, '{}'::jsonb);
END;
$$;

-- ── Rate a Pre-Bootcamp task: 1 = Seen it, 2 = Done it, 3 = Multiple Times ───
-- p_level 0 clears the rating. Values are stored as integers in checklist_completed.
CREATE OR REPLACE FUNCTION public.app_checklist_rate(p_token text, p_skill_code text, p_level int)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id   bigint := app_session_tech_id(p_token);
  v_code      text := NULLIF(trim(p_skill_code), '');
  v_completed jsonb;
BEGIN
  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'Task code is required';
  END IF;

  IF p_level IS NULL OR p_level < 0 OR p_level > 3 THEN
    RAISE EXCEPTION 'Invalid rating level';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.skills sk
    JOIN public.skill_sections sec ON sec.id = sk.section_id
    WHERE sk.skill_code = v_code
      AND sk.active
      AND sec.active
      AND sec.section_type = 'checklist'
      AND sec.checklist_mode = 'rated'
  ) THEN
    RAISE EXCEPTION 'Invalid rated checklist task';
  END IF;

  IF p_level = 0 THEN
    UPDATE public.technicians
    SET checklist_completed = COALESCE(checklist_completed, '{}'::jsonb) - v_code
    WHERE id = v_tech_id AND deleted_at IS NULL
    RETURNING checklist_completed INTO v_completed;
  ELSE
    UPDATE public.technicians
    SET checklist_completed = COALESCE(checklist_completed, '{}'::jsonb) || jsonb_build_object(v_code, p_level)
    WHERE id = v_tech_id AND deleted_at IS NULL
    RETURNING checklist_completed INTO v_completed;
  END IF;

  RETURN COALESCE(v_completed, '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_skills()                              TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_skills()                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_reorder_skills(bigint, bigint[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_session_tech_id(text)                TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_checklist_get(text, bigint)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_checklist_toggle(text, text, boolean)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_checklist_rate(text, text, int)        TO authenticated;
