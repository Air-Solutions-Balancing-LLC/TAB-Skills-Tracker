-- NEBB CT/CP status question on monthly assessment
-- Run in Supabase -> SQL Editor (safe to re-run).

-- Save nebb_status on the technician when they submit an assessment.
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

-- Include nebb_status on admin technician list.
DROP FUNCTION IF EXISTS public.app_admin_list_people();

CREATE OR REPLACE FUNCTION public.app_admin_list_people()
RETURNS TABLE (id bigint, email text, full_name text, role text, region text, deleted boolean, tech_id bigint, nebb_status text, start_date date, latest_raw_scores jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_join text := app_assessment_join_sql('a', 't.id');
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY EXECUTE format($q$
    SELECT p.id,
           p.email,
           COALESCE(p.full_name, t.name) AS full_name,
           p.role,
           t.region,
           (t.deleted_at IS NOT NULL) AS deleted,
           p.tech_id,
           t.nebb_status,
           t.start_date,
           (
             SELECT a.raw_scores::jsonb
             FROM public.assessments a
             WHERE %s
               AND a.raw_scores IS NOT NULL
               AND a.raw_scores::jsonb <> '{}'::jsonb
             ORDER BY a.date DESC
             LIMIT 1
           ) AS latest_raw_scores
    FROM public.app_people p
    LEFT JOIN public.technicians t ON t.id = p.tech_id
    ORDER BY
      CASE p.role WHEN 'admin' THEN 1 WHEN 'pm' THEN 2 ELSE 3 END,
      (t.deleted_at IS NOT NULL),
      lower(COALESCE(p.full_name, t.name, p.email))
  $q$, v_join);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_people() TO authenticated;
