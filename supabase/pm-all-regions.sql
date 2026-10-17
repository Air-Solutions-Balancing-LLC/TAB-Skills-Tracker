-- All Regions support for PM mode.
-- Session region value 'ALL' returns technicians from every region.
-- Safe to re-run.

-- ── Notes/comments: allow PM with All Regions to edit any tech ───────────────
CREATE OR REPLACE FUNCTION public.app_can_edit_tech_notes(p_tech_id bigint, p_token text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_sess_region text;
  v_sess_tech bigint;
BEGIN
  IF p_tech_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_is_admin() THEN
    RETURN true;
  END IF;

  SELECT t.region INTO v_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;

  IF v_region IS NULL THEN
    RETURN false;
  END IF;

  IF p_token IS NULL OR trim(p_token) = '' THEN
    RETURN false;
  END IF;

  SELECT s.tech_id, s.region
    INTO v_sess_tech, v_sess_region
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.expires_at > now();

  IF v_sess_tech IS NOT NULL AND v_sess_tech = p_tech_id THEN
    RETURN true;
  END IF;

  IF v_sess_region IS NOT NULL AND (v_sess_region = 'ALL' OR v_sess_region = v_region) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- ── Training focus: allow PM with All Regions to edit any tech ───────────────
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

    IF v_sess_region IS NULL
       OR (v_sess_region IS DISTINCT FROM 'ALL' AND v_sess_region IS DISTINCT FROM v_region) THEN
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

-- ── PM dashboard: All Regions returns every active technician ────────────────
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
      WHERE t.deleted_at IS NULL
        AND ($1 = 'ALL' OR t.region = $1)
      ORDER BY t.name
    ) x
  $q$, v_join)
  INTO v_result
  USING v_region;

  RETURN v_result;
END;
$$;

-- ── Pre-Bootcamp report: All Regions ─────────────────────────────────────────
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
      (t.pre_bootcamp_updated_at AT TIME ZONE 'America/New_York')::date AS last_update_date
    FROM public.technicians t
    JOIN public.app_people p ON p.tech_id = t.id AND p.role = 'technician'
    WHERE t.deleted_at IS NULL
      AND (v_region = 'ALL' OR t.region = v_region)
      AND jsonb_typeof(t.required_categories) = 'array'
      AND t.required_categories @> '["pre_bootcamp"]'::jsonb
    ORDER BY t.name
  ) x;

  RETURN v_result;
END;
$$;

-- ── ATA PM roster: All Regions → every tech ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_pm_data(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
BEGIN
  SELECT s.region INTO v_region
  FROM sessions s
  WHERE s.token = p_token AND s.expires_at > now();

  IF v_region IS NULL THEN
    RETURN json_build_object('techs', '[]'::json, 'last_import', NULL);
  END IF;

  IF v_region = 'ALL' THEN
    RETURN app_ata_roster_json(NULL);
  END IF;

  RETURN app_ata_roster_json(v_region);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_can_edit_tech_notes(bigint, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_training_focus(bigint, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_dashboard(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_pre_bootcamp_report(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_pm_data(text) TO anon, authenticated;
