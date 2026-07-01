-- Save / resume in-progress monthly assessments
-- Run in Supabase -> SQL Editor (safe to re-run).

ALTER TABLE public.technicians ADD COLUMN IF NOT EXISTS assessment_draft jsonb;

-- Save partial progress for the current month (raw_scores, nebb_status, comment).
CREATE OR REPLACE FUNCTION public.app_save_assessment_draft(p_token text, p_draft jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_month   text := nullif(trim(p_draft->>'month'), '');
BEGIN
  SELECT s.tech_id
  INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token
    AND s.role = 'technician'
    AND s.expires_at > now();

  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_SESSION';
  END IF;

  IF v_month IS NULL OR v_month !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'INVALID_DRAFT_MONTH';
  END IF;

  UPDATE public.technicians
  SET assessment_draft = p_draft
  WHERE id = v_tech_id
    AND deleted_at IS NULL;

  RETURN p_draft;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_assessment_draft(text, jsonb) TO anon, authenticated;

-- Clear draft after final submit (called from app_submit_assessment).
CREATE OR REPLACE FUNCTION public.app_submit_assessment(p_token text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_join    text := app_assessment_join_sql('a', '$1');
  v_date    date := coalesce((p_payload->>'date')::date, current_date);
  v_exists  boolean;
  v_nebb    text := nullif(trim(p_payload->>'nebb_status'), '');
BEGIN
  SELECT s.tech_id
  INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token
    AND s.role = 'technician'
    AND s.expires_at > now();

  IF v_tech_id IS NULL OR v_join = 'false' THEN
    RAISE EXCEPTION 'INVALID_SESSION';
  END IF;

  IF v_nebb IS NULL THEN
    RAISE EXCEPTION 'NEBB_STATUS_REQUIRED';
  END IF;

  EXECUTE format(
    'SELECT EXISTS (
       SELECT 1 FROM assessments a
       WHERE %s
         AND date_trunc(''month'', a.date) = date_trunc(''month'', $2::date)
     )',
    replace(v_join, '$1', '$1')
  )
  INTO v_exists
  USING v_tech_id, v_date;

  IF v_exists THEN
    RAISE EXCEPTION 'ALREADY_SUBMITTED';
  END IF;

  PERFORM app_upsert_assessment_for_tech(
    v_tech_id,
    v_date,
    nullif(p_payload->>'safety_avg', '')::numeric,
    nullif(p_payload->>'basic_avg', '')::numeric,
    nullif(p_payload->>'intermediate_avg', '')::numeric,
    nullif(p_payload->>'advanced_avg', '')::numeric,
    nullif(p_payload->>'survey_avg', '')::numeric,
    nullif(p_payload->>'comment', ''),
    coalesce(p_payload->'raw_scores', '{}'::jsonb)
  );

  UPDATE public.technicians
  SET nebb_status = v_nebb,
      assessment_draft = NULL
  WHERE id = v_tech_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_submit_assessment(text, jsonb) TO anon, authenticated;
