-- Dashboard + submit RPCs for TAB Skills Tracker
-- Run in Supabase → SQL Editor.
--
-- Fixes assessments not appearing when the assessments table uses technician_id
-- but the legacy RPCs joined on tech_id (which does not exist on assessments).
-- Safe to re-run (CREATE OR REPLACE).

-- ── Which column links assessments → technicians ─────────────────────────────
CREATE OR REPLACE FUNCTION public.app_assessments_fk_col()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT column_name
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'assessments'
    AND column_name IN ('technician_id', 'tech_id')
  ORDER BY CASE column_name WHEN 'technician_id' THEN 1 ELSE 2 END
  LIMIT 1;
$$;

-- ── Match NE import rows to a technician id (name match, prefer region NE) ─────
CREATE OR REPLACE FUNCTION public.app_match_technician_id(p_name text)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT t.id
  FROM public.technicians t
  WHERE t.deleted_at IS NULL
    AND lower(trim(t.name)) = lower(trim(p_name))
  ORDER BY CASE WHEN t.region = 'NE' THEN 0 ELSE 1 END, t.id
  LIMIT 1;
$$;

-- ── PM dashboard: technicians in session region + assessment history ───────────
CREATE OR REPLACE FUNCTION public.app_pm_dashboard(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_fk     text := app_assessments_fk_col();
  v_result json;
BEGIN
  SELECT s.region
  INTO v_region
  FROM sessions s
  WHERE s.token = p_token
    AND s.expires_at > now();

  IF v_region IS NULL OR v_fk IS NULL THEN
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
              a.comment,
              a.raw_scores
            FROM assessments a
            WHERE a.%I = t.id
            ORDER BY a.date
          ) a
        ), '[]'::json) AS assessments
      FROM technicians t
      WHERE t.region = $1
        AND t.deleted_at IS NULL
      ORDER BY t.name
    ) x
  $q$, v_fk)
  INTO v_result
  USING v_region;

  RETURN v_result;
END;
$$;

-- ── Technician home: profile + assessment history ────────────────────────────
CREATE OR REPLACE FUNCTION public.app_tech_home(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_fk      text := app_assessments_fk_col();
  v_tech    json;
  v_assess  json;
BEGIN
  SELECT s.tech_id
  INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token
    AND s.role = 'technician'
    AND s.expires_at > now();

  IF v_tech_id IS NULL OR v_fk IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT row_to_json(t)
  INTO v_tech
  FROM technicians t
  WHERE t.id = v_tech_id
    AND t.deleted_at IS NULL;

  IF v_tech IS NULL THEN
    RETURN NULL;
  END IF;

  EXECUTE format($q$
    SELECT coalesce(json_agg(row_to_json(a) ORDER BY a.date), '[]'::json)
    FROM (
      SELECT
        a.date,
        a.safety_avg,
        a.basic_avg,
        a.intermediate_avg,
        a.advanced_avg,
        a.survey_avg,
        a.comment,
        a.raw_scores
      FROM assessments a
      WHERE a.%I = $1
      ORDER BY a.date
    ) a
  $q$, v_fk)
  INTO v_assess
  USING v_tech_id;

  RETURN json_build_object('tech', v_tech, 'assessments', v_assess);
END;
$$;

-- ── Submit monthly assessment ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_submit_assessment(p_token text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_fk      text := app_assessments_fk_col();
  v_date    date := coalesce((p_payload->>'date')::date, current_date);
  v_exists  boolean;
BEGIN
  SELECT s.tech_id
  INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token
    AND s.role = 'technician'
    AND s.expires_at > now();

  IF v_tech_id IS NULL OR v_fk IS NULL THEN
    RAISE EXCEPTION 'INVALID_SESSION';
  END IF;

  EXECUTE format(
    'SELECT EXISTS (
       SELECT 1 FROM assessments a
       WHERE a.%I = $1
         AND date_trunc(''month'', a.date) = date_trunc(''month'', $2::date)
     )',
    v_fk
  )
  INTO v_exists
  USING v_tech_id, v_date;

  IF v_exists THEN
    RAISE EXCEPTION 'ALREADY_SUBMITTED';
  END IF;

  EXECUTE format(
    'INSERT INTO assessments (%I, date, safety_avg, basic_avg, intermediate_avg, advanced_avg, survey_avg, comment, raw_scores)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
    v_fk
  )
  USING
    v_tech_id,
    v_date,
    nullif(p_payload->>'safety_avg', '')::numeric,
    nullif(p_payload->>'basic_avg', '')::numeric,
    nullif(p_payload->>'intermediate_avg', '')::numeric,
    nullif(p_payload->>'advanced_avg', '')::numeric,
    nullif(p_payload->>'survey_avg', '')::numeric,
    nullif(p_payload->>'comment', ''),
    coalesce(p_payload->'raw_scores', '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_assessments_fk_col() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_match_technician_id(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_dashboard(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_home(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_submit_assessment(text, jsonb) TO anon, authenticated;
