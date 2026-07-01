-- RUN THIS ENTIRE FILE in Supabase SQL Editor (one paste). Then hard-refresh app + sign out/in.
-- Combines dashboard RPC fixes + Southwest assessment import.

-- Dashboard + submit RPCs for TAB Skills Tracker
-- Run in Supabase → SQL Editor.
--
-- Reads assessments linked by technician_id OR tech_id (Power Automate vs import).
-- Safe to re-run (CREATE OR REPLACE).

-- ── SQL fragment: assessment row belongs to technician ───────────────────────
CREATE OR REPLACE FUNCTION public.app_assessment_join_sql(p_a_alias text, p_tech_expr text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_has_technician_id boolean;
  v_has_tech_id boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'technician_id'
  ) INTO v_has_technician_id;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'tech_id'
  ) INTO v_has_tech_id;

  IF v_has_technician_id AND v_has_tech_id THEN
    RETURN format(
      '(%I.technician_id = %s OR %I.tech_id = %s)',
      p_a_alias, p_tech_expr, p_a_alias, p_tech_expr
    );
  ELSIF v_has_technician_id THEN
    RETURN format('%I.technician_id = %s', p_a_alias, p_tech_expr);
  ELSIF v_has_tech_id THEN
    RETURN format('%I.tech_id = %s', p_a_alias, p_tech_expr);
  END IF;

  RETURN 'false';
END;
$$;

-- ── Which column links assessments → technicians (legacy helper) ───────────────
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

-- ── Match import rows to a technician id (name match, prefer region) ───────────
DROP FUNCTION IF EXISTS public.app_match_technician_id(text);
CREATE OR REPLACE FUNCTION public.app_match_technician_id(p_name text, p_region text DEFAULT NULL)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT t.id
  FROM public.technicians t
  WHERE t.deleted_at IS NULL
    AND lower(trim(t.name)) = lower(trim(p_name))
  ORDER BY
    CASE
      WHEN p_region IS NOT NULL AND t.region = p_region THEN 0
      WHEN p_region IS NULL AND t.region = 'NE' THEN 0
      ELSE 1
    END,
    t.id
  LIMIT 1;
$$;

-- ── Upsert one assessment row (dynamic SQL — works with technician_id and/or tech_id) ─
CREATE OR REPLACE FUNCTION public.app_upsert_assessment_for_tech(
  p_tech_id bigint,
  p_date date,
  p_safety_avg numeric,
  p_basic_avg numeric,
  p_intermediate_avg numeric,
  p_advanced_avg numeric,
  p_survey_avg numeric,
  p_comment text,
  p_raw_scores jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_technician_id boolean;
  v_has_tech_id boolean;
  v_updated integer;
BEGIN
  IF p_tech_id IS NULL OR p_date IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'technician_id'
  ) INTO v_has_technician_id;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'assessments' AND column_name = 'tech_id'
  ) INTO v_has_tech_id;

  IF NOT v_has_technician_id AND NOT v_has_tech_id THEN
    RETURN;
  END IF;

  IF v_has_technician_id AND v_has_tech_id THEN
    EXECUTE $sql$
      UPDATE public.assessments a
      SET safety_avg = $3, basic_avg = $4, intermediate_avg = $5, advanced_avg = $6,
          survey_avg = $7, comment = $8, raw_scores = $9,
          technician_id = coalesce(a.technician_id, $1),
          tech_id = coalesce(a.tech_id, $1)
      WHERE a.date = $2 AND (a.technician_id = $1 OR a.tech_id = $1)
    $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
              p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
  ELSIF v_has_technician_id THEN
    EXECUTE $sql$
      UPDATE public.assessments a
      SET safety_avg = $3, basic_avg = $4, intermediate_avg = $5, advanced_avg = $6,
          survey_avg = $7, comment = $8, raw_scores = $9
      WHERE a.technician_id = $1 AND a.date = $2
    $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
              p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
  ELSE
    EXECUTE $sql$
      UPDATE public.assessments a
      SET safety_avg = $3, basic_avg = $4, intermediate_avg = $5, advanced_avg = $6,
          survey_avg = $7, comment = $8, raw_scores = $9
      WHERE a.tech_id = $1 AND a.date = $2
    $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
              p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
  END IF;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated > 0 THEN
    RETURN;
  END IF;

  BEGIN
    IF v_has_technician_id AND v_has_tech_id THEN
      EXECUTE $sql$
        INSERT INTO public.assessments (
          technician_id, tech_id, date, safety_avg, basic_avg, intermediate_avg,
          advanced_avg, survey_avg, comment, raw_scores
        ) VALUES ($1, $1, $2, $3, $4, $5, $6, $7, $8, $9)
      $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
                p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
    ELSIF v_has_technician_id THEN
      EXECUTE $sql$
        INSERT INTO public.assessments (
          technician_id, date, safety_avg, basic_avg, intermediate_avg,
          advanced_avg, survey_avg, comment, raw_scores
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
                p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
    ELSE
      EXECUTE $sql$
        INSERT INTO public.assessments (
          tech_id, date, safety_avg, basic_avg, intermediate_avg,
          advanced_avg, survey_avg, comment, raw_scores
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
                p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    IF v_has_technician_id AND v_has_tech_id THEN
      EXECUTE $sql$
        UPDATE public.assessments a
        SET safety_avg = $3, basic_avg = $4, intermediate_avg = $5, advanced_avg = $6,
            survey_avg = $7, comment = $8, raw_scores = $9,
            technician_id = coalesce(a.technician_id, $1),
            tech_id = coalesce(a.tech_id, $1)
        WHERE a.date = $2 AND (a.technician_id = $1 OR a.tech_id = $1)
      $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
                p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
    ELSIF v_has_technician_id THEN
      EXECUTE $sql$
        UPDATE public.assessments a
        SET safety_avg = $3, basic_avg = $4, intermediate_avg = $5, advanced_avg = $6,
            survey_avg = $7, comment = $8, raw_scores = $9
        WHERE a.technician_id = $1 AND a.date = $2
      $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
                p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
    ELSE
      EXECUTE $sql$
        UPDATE public.assessments a
        SET safety_avg = $3, basic_avg = $4, intermediate_avg = $5, advanced_avg = $6,
            survey_avg = $7, comment = $8, raw_scores = $9
        WHERE a.tech_id = $1 AND a.date = $2
      $sql$ USING p_tech_id, p_date, p_safety_avg, p_basic_avg, p_intermediate_avg,
                p_advanced_avg, p_survey_avg, p_comment, p_raw_scores;
    END IF;
  END;
END;
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
  v_join    text := app_assessment_join_sql('a', '$1');
  v_tech    json;
  v_assess  json;
BEGIN
  SELECT s.tech_id
  INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token
    AND s.role = 'technician'
    AND s.expires_at > now();

  IF v_tech_id IS NULL OR v_join = 'false' THEN
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
      WHERE %s
      ORDER BY a.date
    ) a
  $q$, v_join)
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
  v_join    text := app_assessment_join_sql('a', '$1');
  v_date    date := coalesce((p_payload->>'date')::date, current_date);
  v_exists  boolean;
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
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_assessment_join_sql(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_assessments_fk_col() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_match_technician_id(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_assessment_for_tech(bigint, date, numeric, numeric, numeric, numeric, numeric, text, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_dashboard(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_home(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_submit_assessment(text, jsonb) TO anon, authenticated;


SELECT app_upsert_assessment_for_tech(
  app_match_technician_id(v.tech_name, 'KES'),
  CASE
    WHEN v.mode = 'latest' THEN coalesce(
      (SELECT max(a.date)
       FROM public.assessments a
       WHERE a.technician_id = app_match_technician_id(v.tech_name, 'KES')),
      v.fallback_date::date
    )
    ELSE v.assessment_date::date
  END,
  v.safety_avg,
  v.basic_avg,
  v.intermediate_avg,
  v.advanced_avg,
  v.survey_avg,
  v.comment,
  v.raw_scores
)
FROM (VALUES
  ('Alex Barajas', 'dated', '2026-03-28', '2025-09-30', 4.23, 4.55, NULL, NULL, NULL, NULL, '{"s1":5,"s2":4,"s3":5,"s4":5,"s5":2,"s6":4,"s7":4,"s8":5,"s9":3,"s10":4,"s11":5,"s12":4,"s13":5,"b1":5,"b2":5,"b3":5,"b4":5,"b5":5,"b6":5,"b7":5,"b8":5,"b9":5,"b10":3,"b11":5,"b12":5,"b13":5,"b14":5,"b15":5,"b16":4,"b17":5,"b18":5,"b19":5,"b20":5,"b21":3,"b22":3,"b23":5,"b24":5,"b25":5,"b26":5,"b27":5,"b28":2,"b29":3,"b30":5,"b31":5,"b32":5,"b33":4,"b34":5,"b35":5,"b36":3,"b37":3,"b38":5}'::jsonb),
  ('Paul Samuelson', 'dated', '2026-05-06', '2026-05-06', 2.62, 2.26, 1.7, 1.04, 1, NULL, '{"s1":2,"s2":2,"s3":1,"s4":3,"s5":2,"s6":3,"s7":3,"s8":3,"s9":3,"s10":3,"s11":3,"s12":3,"s13":3,"b1":1,"b2":2,"b3":2,"b4":2,"b5":1,"b6":2,"b7":2,"b8":2,"b9":4,"b10":1,"b11":1,"b12":3,"b13":3,"b14":1,"b15":4,"b16":3,"b17":4,"b18":4,"b19":2,"b20":1,"b21":1,"b22":1,"b23":4,"b24":2,"b25":4,"b26":3,"b27":3,"b28":1,"b29":3,"b30":1,"b31":2,"b32":4,"b33":2,"b34":2,"b35":2,"b36":1,"b37":1,"b38":4,"i2":2,"i3":1,"i4":1,"i5":1,"i6":3,"i7":4,"i8":1,"i9":3,"i10":4,"i11":2,"i12":1,"i13":1,"i14":1,"i15":1,"i16":4,"i17":4,"i18":4,"i19":4,"i20":1,"i21":2,"i22":1,"i23":1,"i24":2,"i25":1,"i26":1,"i27":1,"i28":1,"i29":1,"i30":1,"i31":1,"i32":1,"i33":1,"i34":1,"i35":1,"i36":1,"i37":1,"i38":1,"i39":1,"i40":1,"i41":3,"i42":2,"i43":1,"i44":2,"a1":2,"a3":1,"a4":1,"a5":1,"a6":1,"a7":1,"a8":1,"a9":1,"a10":1,"a11":1,"a12":1,"a13":1,"a14":1,"a15":1,"a16":1,"a17":1,"a18":1,"a19":1,"a20":1,"a21":1,"a22":1,"a23":1,"a24":1,"a25":1,"a26":1,"a27":1,"a28":1,"sv1":1,"sv2":1}'::jsonb),
  ('John Turner', 'dated', '2026-05-07', '2026-05-07', 5, 4.79, 4.37, 2.22, 2, NULL, '{"s1":5,"s2":5,"s3":5,"s4":5,"s5":5,"s6":5,"s7":5,"s8":5,"s9":5,"s10":5,"s11":5,"s12":5,"s13":5,"b1":5,"b2":5,"b3":5,"b4":5,"b5":5,"b6":5,"b7":5,"b8":5,"b9":5,"b10":3,"b11":5,"b12":5,"b13":5,"b14":5,"b15":5,"b16":5,"b17":5,"b18":5,"b19":5,"b20":5,"b21":3,"b22":5,"b23":5,"b24":5,"b25":5,"b26":5,"b27":5,"b28":3,"b29":5,"b30":5,"b31":5,"b32":5,"b33":5,"b34":5,"b35":5,"b36":3,"b37":5,"b38":5,"i2":5,"i3":5,"i4":5,"i5":5,"i6":5,"i7":5,"i8":5,"i9":5,"i10":5,"i11":5,"i12":5,"i13":3,"i14":5,"i15":5,"i16":5,"i17":5,"i18":5,"i19":5,"i20":3,"i21":5,"i22":5,"i23":3,"i24":5,"i25":3,"i26":3,"i27":3,"i28":3,"i29":3,"i30":3,"i31":3,"i32":5,"i33":5,"i34":5,"i35":5,"i36":5,"i37":5,"i38":5,"i39":2,"i40":3,"i41":5,"i42":5,"i43":3,"i44":5,"a1":5,"a3":2,"a4":2,"a5":2,"a6":2,"a7":2,"a8":2,"a9":3,"a10":1,"a11":2,"a12":2,"a13":2,"a14":2,"a15":2,"a16":3,"a17":2,"a18":2,"a19":2,"a20":2,"a21":2,"a22":2,"a23":4,"a24":2,"a25":2,"a26":2,"a27":2,"a28":2,"sv1":2,"sv2":2}'::jsonb),
  ('Zander Caron-Mitchell', 'dated', '2026-03-30', NULL, 4.62, 3.13, 1.68, 1, NULL, NULL, '{"s1":5,"s2":5,"s3":4,"s4":5,"s5":4,"s6":5,"s7":5,"s8":5,"s9":5,"s10":4,"s11":5,"s12":5,"s13":3,"b1":3,"b2":3,"b3":2,"b4":3,"b5":3,"b6":2,"b7":5,"b8":2,"b9":4,"b10":1,"b11":4,"b12":4,"b13":4,"b14":4,"b15":4,"b16":4,"b17":5,"b18":4,"b19":4,"b20":4,"b21":1,"b22":1,"b23":4,"b24":4,"b25":4,"b26":4,"b27":4,"b28":1,"b29":1,"b30":3,"b31":1,"b32":4,"b33":4,"b34":4,"b35":4,"b36":1,"b37":1,"b38":4,"i2":1,"i3":1,"i4":1,"i5":1,"i6":4,"i7":4,"i8":1,"i9":3,"i10":4,"i11":1,"i13":1,"i14":1,"i15":1,"i16":4,"i17":4,"i18":4,"i19":3,"i20":1,"i21":2,"i22":1,"i23":1,"i24":3,"i25":1,"i26":1,"i27":1,"i28":1,"i29":1,"i30":1,"i31":1,"i32":1,"i33":1,"i35":1,"i36":3,"i37":1,"i38":1,"i39":1,"i40":1,"i41":2,"i42":1,"i43":1,"i44":1,"a1":1}'::jsonb)
) AS v(tech_name, mode, assessment_date, fallback_date, safety_avg, basic_avg, intermediate_avg, advanced_avg, survey_avg, comment, raw_scores)
WHERE app_match_technician_id(v.tech_name, 'KES') IS NOT NULL;

-- Verify
SELECT 'sample_latest' AS check_name, t.name, max(a.date) AS latest_date, count(*) AS total
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE t.region = 'KES' AND t.deleted_at IS NULL
GROUP BY t.id, t.name
ORDER BY t.name;

SELECT 'june_2026_count' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region = 'KES' AND t.deleted_at IS NULL AND a.date >= '2026-06-01';
