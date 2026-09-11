-- Pre-Bootcamp Assessment Report
-- Run in Supabase -> SQL Editor AFTER supabase/checklist.sql and supabase/admin-reports.sql.
-- Safe to re-run.

-- Track when a technician last rated any Pre-Bootcamp item
ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS pre_bootcamp_updated_at timestamptz;

-- Stamp last Pre-Bootcamp activity on each rating change
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
    SET checklist_completed = COALESCE(checklist_completed, '{}'::jsonb) - v_code,
        pre_bootcamp_updated_at = now()
    WHERE id = v_tech_id AND deleted_at IS NULL
    RETURNING checklist_completed INTO v_completed;
  ELSE
    UPDATE public.technicians
    SET checklist_completed = COALESCE(checklist_completed, '{}'::jsonb) || jsonb_build_object(v_code, p_level),
        pre_bootcamp_updated_at = now()
    WHERE id = v_tech_id AND deleted_at IS NULL
    RETURNING checklist_completed INTO v_completed;
  END IF;

  RETURN COALESCE(v_completed, '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_checklist_rate(text, text, int) TO authenticated;

-- Techs currently required for Pre-Bootcamp (≤100 days employed AND before bootcamp start)
CREATE OR REPLACE FUNCTION public.app_admin_pre_bootcamp_report()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result json;
  v_total  int;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT count(*)::int INTO v_total
  FROM public.skills sk
  JOIN public.skill_sections sec ON sec.id = sk.section_id
  WHERE sec.skey = 'pre_bootcamp'
    AND sk.active
    AND sec.active;

  SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.name, x.region NULLS LAST), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id AS tech_id,
      t.name,
      t.region,
      t.start_date,
      t.bootcamp_start_date,
      CASE
        WHEN t.start_date IS NULL THEN NULL
        ELSE (current_date - t.start_date::date)::int
      END AS days_employed,
      CASE
        WHEN coalesce(v_total, 0) = 0 THEN 0
        ELSE (
          SELECT round(
            (
              SELECT coalesce(sum(
                CASE
                  WHEN jsonb_typeof(t.checklist_completed -> sk.skill_code) = 'number'
                    THEN round((((t.checklist_completed ->> sk.skill_code)::numeric) / 3.0) * 100)
                  WHEN (t.checklist_completed ->> sk.skill_code) = 'true'
                    THEN 67
                  ELSE 0
                END
              ), 0)
              FROM public.skills sk
              JOIN public.skill_sections sec ON sec.id = sk.section_id
              WHERE sec.skey = 'pre_bootcamp'
                AND sk.active
                AND sec.active
            )::numeric / v_total
          )::int
        )
      END AS progress_pct,
      (t.pre_bootcamp_updated_at AT TIME ZONE 'America/New_York')::date AS last_update_date,
      CASE
        WHEN t.pre_bootcamp_updated_at IS NULL THEN NULL
        ELSE (current_date - (t.pre_bootcamp_updated_at AT TIME ZONE 'America/New_York')::date)::int
      END AS days_since_update
    FROM public.technicians t
    JOIN public.app_people p ON p.tech_id = t.id AND p.role = 'technician'
    WHERE t.deleted_at IS NULL
      AND t.start_date IS NOT NULL
      AND (current_date - t.start_date::date) <= 100
      AND (
        t.bootcamp_start_date IS NULL
        OR current_date < t.bootcamp_start_date::date
      )
  ) x;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_pre_bootcamp_report() TO authenticated;
