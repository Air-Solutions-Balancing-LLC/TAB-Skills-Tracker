-- Allow PM or Admin to save Training Focus while viewing a technician.
-- Also include training_focus fields on the PM dashboard payload.
-- Safe to re-run.

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS training_focus text,
  ADD COLUMN IF NOT EXISTS training_goal_start date,
  ADD COLUMN IF NOT EXISTS training_goal_end date;

CREATE OR REPLACE FUNCTION public.app_save_training_focus(
  p_tech_id bigint,
  p_focus text DEFAULT NULL,
  p_goal_start text DEFAULT NULL,
  p_goal_end text DEFAULT NULL,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_sess_region text;
  v_focus text := nullif(trim(coalesce(p_focus, '')), '');
  v_start date;
  v_end date;
BEGIN
  IF p_tech_id IS NULL THEN
    RAISE EXCEPTION 'missing_tech';
  END IF;

  SELECT t.region INTO v_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;

  IF v_region IS NULL THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  IF app_is_admin() THEN
    NULL; -- ok
  ELSIF p_token IS NOT NULL AND trim(p_token) <> '' THEN
    SELECT s.region INTO v_sess_region
    FROM public.sessions s
    WHERE s.token = p_token
      AND s.expires_at > now()
      AND s.region IS NOT NULL;

    IF v_sess_region IS NULL OR v_sess_region IS DISTINCT FROM v_region THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
  ELSE
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_start := CASE
    WHEN p_goal_start IS NULL OR trim(p_goal_start) = '' THEN NULL
    ELSE p_goal_start::date
  END;
  v_end := CASE
    WHEN p_goal_end IS NULL OR trim(p_goal_end) = '' THEN NULL
    ELSE p_goal_end::date
  END;

  UPDATE public.technicians
     SET training_focus = v_focus,
         training_goal_start = v_start,
         training_goal_end = v_end
   WHERE id = p_tech_id
     AND deleted_at IS NULL;

  RETURN json_build_object(
    'ok', true,
    'training_focus', v_focus,
    'training_goal_start', v_start,
    'training_goal_end', v_end
  );
END;
$$;

-- PM dashboard: include training focus so it shows when opening a tech.
CREATE OR REPLACE FUNCTION public.app_pm_dashboard(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_join   text := app_assessment_join_sql('a', 't.id');
  v_result json;
BEGIN
  SELECT s.region
  INTO v_region
  FROM sessions s
  WHERE s.token = p_token
    AND s.expires_at > now();

  IF v_region IS NULL OR v_join = 'false' THEN
    RETURN '[]'::json;
  END IF;

  EXECUTE format($q$
    SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.name), '[]'::json)
    FROM (
      SELECT
        t.id,
        t.name,
        t.region,
        t.nebb_status,
        t.lead_tech,
        t.start_date,
        t.bootcamp_start_date,
        t.notes_to_tech,
        t.tech_comments,
        t.training_focus,
        t.training_goal_start,
        t.training_goal_end,
        t.job_position,
        t.required_categories,
        t.cert_expires_on,
        t.cecs_complete,
        t.nebb_site_updated,
        coalesce((
          SELECT json_agg(row_to_json(a) ORDER BY a.date)
          FROM (
            SELECT
              a.date,
              a.safety_avg,
              a.basic_avg,
              a.intermediate_avg,
              a.advanced_avg,
              a.survey_avg,
              a.national_accounts_avg,
              a.comment,
              a.raw_scores
            FROM assessments a
            WHERE %s
            ORDER BY a.date
          ) a
        ), '[]'::json) AS assessments
      FROM technicians t
      WHERE t.region = $1
        AND t.deleted_at IS NULL
      ORDER BY t.name
    ) x
  $q$, v_join)
  INTO v_result
  USING v_region;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_training_focus(bigint, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_dashboard(text) TO anon, authenticated;
