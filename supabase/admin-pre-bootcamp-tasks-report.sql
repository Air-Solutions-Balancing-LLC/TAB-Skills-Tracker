-- Admin Pre-Bootcamp Tasks Report (all regions).
-- Run in Supabase -> SQL Editor (safe to re-run).
-- Also included at the end of supabase/pm-pre-bootcamp-report.sql.

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
