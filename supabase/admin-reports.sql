-- Admin reports for TAB Skills Tracker
-- Run in Supabase -> SQL Editor AFTER supabase/admin.sql and assessments-rpcs.sql.
-- Safe to re-run (CREATE OR REPLACE).

-- ── Technician activity: last update, staleness, skills changed since prior submission ─
CREATE OR REPLACE FUNCTION public.app_admin_technician_activity_report()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_fk_col text;
  v_result json;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_fk_col := app_assessments_fk_col();
  IF v_fk_col IS NULL THEN
    RETURN '[]'::json;
  END IF;

  EXECUTE format($q$
    SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.region NULLS LAST, x.name), '[]'::json)
    FROM (
      SELECT
        t.id AS tech_id,
        t.name,
        t.region,
        l.last_update_date,
        CASE
          WHEN l.last_update_date IS NULL THEN NULL
          ELSE (current_date - l.last_update_date)::int
        END AS days_since_update,
        coalesce(l.assessment_count, 0)::int AS assessment_count,
        CASE
          WHEN coalesce(l.assessment_count, 0) < 2 THEN NULL
          ELSE (
            SELECT count(*)::int
            FROM (
              SELECT keys.key
              FROM (
                SELECT jsonb_object_keys(coalesce(l.latest_raw, '{}'::jsonb)) AS key
                UNION
                SELECT jsonb_object_keys(coalesce(p.prev_raw, '{}'::jsonb)) AS key
              ) keys
              WHERE coalesce(l.latest_raw -> keys.key, 'null'::jsonb)
                    IS DISTINCT FROM coalesce(p.prev_raw -> keys.key, 'null'::jsonb)
            ) diff
          )
        END AS skills_changed
      FROM public.technicians t
      LEFT JOIN LATERAL (
        SELECT
          r.date AS last_update_date,
          r.raw_scores AS latest_raw,
          r.assessment_count
        FROM (
          SELECT
            a.date,
            a.raw_scores,
            row_number() OVER (ORDER BY a.date DESC) AS rn,
            count(*) OVER () AS assessment_count
          FROM public.assessments a
          WHERE a.%1$I = t.id
        ) r
        WHERE r.rn = 1
      ) l ON true
      LEFT JOIN LATERAL (
        SELECT r.raw_scores AS prev_raw
        FROM (
          SELECT
            a.raw_scores,
            row_number() OVER (ORDER BY a.date DESC) AS rn
          FROM public.assessments a
          WHERE a.%1$I = t.id
        ) r
        WHERE r.rn = 2
      ) p ON true
      WHERE t.deleted_at IS NULL
    ) x
  $q$, v_fk_col)
  INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_technician_activity_report() TO authenticated;
