-- Pre-Bootcamp Assessment Report: only techs with Pre-Bootcamp category selected.
-- Run in Supabase -> SQL Editor (safe to re-run).
-- Updates app_admin_pre_bootcamp_report() filter from bootcamp start date
-- to required_categories containing "pre_bootcamp".

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
  v_today  date := (timezone('America/New_York', now()))::date;
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
        ELSE (v_today - t.start_date::date)::int
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
        ELSE (v_today - (t.pre_bootcamp_updated_at AT TIME ZONE 'America/New_York')::date)::int
      END AS days_since_update
    FROM public.technicians t
    JOIN public.app_people p ON p.tech_id = t.id AND p.role = 'technician'
    WHERE t.deleted_at IS NULL
      AND jsonb_typeof(t.required_categories) = 'array'
      AND t.required_categories @> '["pre_bootcamp"]'::jsonb
  ) x;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_pre_bootcamp_report() TO authenticated;
