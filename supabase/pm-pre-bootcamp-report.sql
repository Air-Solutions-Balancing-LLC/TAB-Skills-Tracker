-- PM Pre-Bootcamp Report
-- Techs in the PM's region with Pre-Bootcamp selected, plus checklist ratings.
-- Run in Supabase -> SQL Editor (safe to re-run).
-- last_assessment_date is the latest skills assessment, not the checklist rating.

CREATE OR REPLACE FUNCTION public.app_last_assessment_date(p_tech_id bigint)
RETURNS date
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_date date;
  v_join text;
BEGIN
  IF p_tech_id IS NULL THEN
    RETURN NULL;
  END IF;
  v_join := public.app_assessment_join_sql('a', '$1');
  IF v_join IS NULL OR v_join = 'false' THEN
    RETURN NULL;
  END IF;
  EXECUTE format('SELECT max(a.date) FROM public.assessments a WHERE %s', v_join)
    INTO v_date
    USING p_tech_id;
  RETURN v_date;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_last_assessment_date(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_pm_pre_bootcamp_report(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_result json;
BEGIN
  SELECT s.region
  INTO v_region
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.expires_at > now()
  LIMIT 1;

  IF v_region IS NULL THEN
    RETURN '[]'::json;
  END IF;

  SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.name), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id AS tech_id,
      t.name,
      t.region,
      t.bootcamp_start_date,
      t.required_categories,
      coalesce(t.checklist_completed, '{}'::jsonb) AS checklist_completed,
      public.app_last_assessment_date(t.id) AS last_assessment_date,
      (t.pre_bootcamp_updated_at AT TIME ZONE 'America/New_York')::date AS last_update_date
    FROM public.technicians t
    JOIN public.app_people p ON p.tech_id = t.id AND p.role = 'technician'
    WHERE t.deleted_at IS NULL
      AND t.region = v_region
      AND jsonb_typeof(t.required_categories) = 'array'
      AND t.required_categories @> '["pre_bootcamp"]'::jsonb
    ORDER BY t.name
  ) x;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_pm_pre_bootcamp_report(text) TO anon, authenticated;

-- Admin: same task detail for all regions (Pre-Bootcamp category selected).
CREATE OR REPLACE FUNCTION public.app_admin_pre_bootcamp_tasks_report()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.region NULLS LAST, x.name), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id AS tech_id,
      t.name,
      t.region,
      t.bootcamp_start_date,
      t.required_categories,
      coalesce(t.checklist_completed, '{}'::jsonb) AS checklist_completed,
      public.app_last_assessment_date(t.id) AS last_assessment_date,
      (t.pre_bootcamp_updated_at AT TIME ZONE 'America/New_York')::date AS last_update_date
    FROM public.technicians t
    JOIN public.app_people p ON p.tech_id = t.id AND p.role = 'technician'
    WHERE t.deleted_at IS NULL
      AND jsonb_typeof(t.required_categories) = 'array'
      AND t.required_categories @> '["pre_bootcamp"]'::jsonb
    ORDER BY t.region NULLS LAST, t.name
  ) x;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_pre_bootcamp_tasks_report() TO authenticated;
