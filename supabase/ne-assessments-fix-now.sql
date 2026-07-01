-- RUN THIS ENTIRE FILE in Supabase SQL Editor (one paste). Then hard-refresh app + sign out/in.
-- Combines dashboard RPC fixes + 8 missing Apr-Jun 2026 NE assessment rows.

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
GRANT EXECUTE ON FUNCTION public.app_match_technician_id(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_assessment_for_tech(bigint, date, numeric, numeric, numeric, numeric, numeric, text, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_dashboard(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_home(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_submit_assessment(text, jsonb) TO anon, authenticated;

SELECT app_upsert_assessment_for_tech(
  app_match_technician_id(replace(v.tech_name, '''''', '''')),
  v.assessment_date,
  v.safety_avg,
  v.basic_avg,
  v.intermediate_avg,
  v.advanced_avg,
  v.survey_avg,
  v.comment,
  v.raw_scores
)
FROM (VALUES
  ('Andrew Parziale', '2026-05-05'::date, 4.62, 3.84, NULL::numeric, NULL::numeric, NULL::numeric, NULL::text, '{"s1":4,"s2":4,"s3":4,"s4":4,"s5":4,"s6":5,"s7":5,"s8":5,"s9":5,"s10":5,"s11":5,"s12":5,"s13":5,"b1":5,"b2":4,"b3":5,"b4":5,"b5":5,"b6":4,"b7":3,"b8":3,"b9":4,"b10":4,"b11":4,"b12":4,"b13":4,"b14":4,"b15":4,"b16":3,"b17":4,"b18":3,"b19":4,"b20":3,"b21":3,"b22":4,"b23":4,"b24":4,"b25":4,"b26":4,"b27":4,"b28":4,"b29":3,"b30":4,"b31":3,"b32":4,"b33":4,"b34":4,"b35":4,"b36":4,"b37":4,"b38":2}'::jsonb),
  ('Dom Jean-Louis', '2026-06-03'::date, 4.31, 3.0, NULL::numeric, NULL::numeric, NULL::numeric, NULL::text, '{"s1":4,"s2":4,"s3":4,"s4":4,"s5":4,"s6":5,"s7":4,"s8":5,"s9":5,"s10":4,"s11":4,"s12":4,"s13":5,"b1":4,"b2":3,"b3":3,"b4":3,"b5":3,"b6":2,"b7":2,"b8":2,"b9":4,"b10":4,"b11":4,"b12":3,"b13":3,"b14":2,"b15":3,"b16":3,"b17":3,"b18":2,"b19":3,"b20":2,"b21":4,"b22":4,"b23":3,"b24":3,"b25":3,"b26":3,"b27":3,"b28":3,"b29":3,"b30":3,"b31":3,"b32":3,"b33":3,"b34":3,"b35":3,"b36":3,"b37":3,"b38":3}'::jsonb),
  ('Dylan Conner', '2026-06-03'::date, 4.54, 4.26, 4.12, 3.85, 3.5, NULL::text, '{"s1":4,"s2":4,"s3":4,"s4":4,"s5":4,"s6":5,"s7":5,"s8":5,"s9":5,"s10":5,"s11":5,"s12":5,"s13":4,"b1":5,"b2":4,"b3":5,"b4":5,"b5":5,"b6":5,"b7":4,"b8":4,"b9":4,"b10":5,"b11":5,"b12":5,"b13":3,"b14":4,"b15":5,"b16":2,"b17":4,"b18":3,"b19":4,"b20":4,"b21":4,"b22":5,"b23":5,"b24":5,"b25":4,"b26":5,"b27":4,"b28":5,"b29":3,"b30":4,"b31":5,"b32":4,"b33":5,"b34":5,"b35":4,"b36":4,"b37":5,"b38":1,"i2":4,"i3":4,"i4":4,"i5":4,"i6":4,"i7":1,"i8":5,"i9":5,"i10":5,"i11":4,"i12":4,"i13":4,"i14":4,"i15":4,"i16":5,"i17":5,"i18":5,"i19":5,"i20":4,"i21":3,"i22":4,"i23":4,"i24":4,"i25":4,"i26":4,"i27":4,"i28":4,"i29":4,"i30":4,"i31":4,"i32":4,"i33":4,"i34":4,"i35":5,"i36":5,"i37":4,"i38":4,"i39":4,"i40":4,"i41":4,"i42":4,"i43":4,"i44":4,"a1":4,"a3":4,"a4":4,"a5":4,"a6":4,"a7":4,"a8":4,"a9":4,"a10":4,"a11":5,"a12":4,"a13":4,"a14":4,"a15":4,"a16":4,"a17":4,"a18":4,"a19":4,"a20":4,"a21":4,"a22":2,"a23":2,"a24":2,"a25":4,"a26":5,"a27":4,"a28":4,"sv1":3,"sv2":4}'::jsonb),
  ('James Dupass', '2026-04-30'::date, 4.0, 3.92, 3.86, 3.07, 2.0, NULL::text, '{"s1":4,"s2":4,"s3":4,"s4":4,"s5":4,"s6":4,"s7":4,"s8":4,"s9":4,"s10":4,"s11":4,"s12":4,"s13":4,"b1":4,"b2":4,"b3":4,"b4":4,"b5":4,"b6":4,"b7":4,"b8":4,"b9":4,"b10":4,"b11":4,"b12":4,"b13":1,"b14":4,"b15":4,"b16":4,"b17":4,"b18":4,"b19":4,"b20":4,"b21":4,"b22":4,"b23":4,"b24":4,"b25":4,"b26":4,"b27":4,"b28":4,"b29":4,"b30":4,"b31":4,"b32":4,"b33":4,"b34":4,"b35":4,"b36":4,"b37":4,"b38":4,"i2":4,"i3":4,"i4":4,"i5":4,"i6":4,"i7":1,"i8":4,"i9":4,"i10":4,"i11":4,"i12":4,"i13":4,"i14":4,"i15":4,"i16":4,"i17":4,"i18":4,"i19":4,"i20":4,"i21":4,"i22":4,"i23":4,"i24":4,"i25":4,"i26":4,"i27":4,"i28":4,"i29":4,"i30":4,"i31":4,"i32":4,"i33":4,"i34":4,"i35":4,"i36":4,"i37":4,"i38":4,"i39":4,"i40":4,"i41":4,"i42":4,"i43":1,"i44":4,"a1":4,"a3":4,"a4":4,"a5":4,"a6":4,"a7":4,"a8":4,"a9":4,"a10":4,"a11":2,"a12":4,"a13":4,"a14":4,"a15":4,"a16":4,"a17":1,"a18":4,"a19":4,"a20":4,"a21":4,"a22":1,"a23":1,"a24":1,"a25":1,"a26":1,"a27":1,"a28":2,"sv1":1,"sv2":3}'::jsonb),
  ('Kody Collins', '2026-06-04'::date, 4.77, 4.74, NULL::numeric, NULL::numeric, NULL::numeric, NULL::text, '{"s1":5,"s2":5,"s3":5,"s4":5,"s5":4,"s6":5,"s7":4,"s8":5,"s9":4,"s10":5,"s11":5,"s12":5,"s13":5,"b1":5,"b2":5,"b3":5,"b4":5,"b5":5,"b6":5,"b7":4,"b8":5,"b9":5,"b10":5,"b11":5,"b12":5,"b13":5,"b14":4,"b15":5,"b16":5,"b17":4,"b18":4,"b19":4,"b20":5,"b21":5,"b22":5,"b23":5,"b24":5,"b25":5,"b26":5,"b27":5,"b28":5,"b29":4,"b30":5,"b31":5,"b32":5,"b33":5,"b34":5,"b35":5,"b36":5,"b37":5,"b38":1}'::jsonb),
  ('Kurt Paradis', '2026-06-03'::date, 5.0, 4.68, 4.74, 3.63, 2.5, 'I have yet to do any KES surveys', '{"s1":5,"s2":5,"s3":5,"s4":5,"s5":5,"s6":5,"s7":5,"s8":5,"s9":5,"s10":5,"s11":5,"s12":5,"s13":5,"b1":5,"b2":5,"b3":5,"b4":5,"b5":5,"b6":5,"b7":5,"b8":5,"b9":5,"b10":5,"b11":5,"b12":5,"b13":5,"b14":4,"b15":5,"b16":2,"b17":5,"b18":3,"b19":5,"b20":5,"b21":5,"b22":5,"b23":5,"b24":5,"b25":5,"b26":5,"b27":5,"b28":5,"b29":4,"b30":4,"b31":5,"b32":5,"b33":5,"b34":5,"b35":5,"b36":5,"b37":5,"b38":1,"i2":5,"i3":4,"i4":5,"i5":5,"i6":5,"i7":5,"i8":5,"i9":5,"i10":5,"i11":5,"i12":5,"i13":5,"i14":5,"i15":5,"i16":5,"i17":5,"i18":5,"i19":5,"i20":5,"i21":5,"i22":5,"i23":5,"i24":5,"i25":5,"i26":5,"i27":5,"i28":5,"i29":3,"i30":5,"i31":4,"i32":4,"i33":5,"i34":4,"i35":5,"i36":5,"i37":5,"i38":4,"i39":5,"i40":4,"i41":5,"i42":5,"i43":3,"i44":4,"a1":3,"a3":4,"a4":3,"a5":3,"a6":4,"a7":4,"a8":4,"a9":4,"a10":5,"a11":4,"a12":3,"a13":5,"a14":5,"a15":4,"a16":4,"a17":3,"a18":4,"a19":5,"a20":5,"a21":3,"a22":4,"a23":4,"a24":1,"a25":3,"a26":3,"a27":3,"a28":1,"sv1":2,"sv2":3}'::jsonb),
  ('Matt O''Brien', '2026-06-03'::date, 4.08, 3.68, NULL::numeric, NULL::numeric, NULL::numeric, 'For me this was my first assessment,  and I think it will be helpful going forward.', '{"s1":4,"s2":3,"s3":3,"s4":4,"s5":3,"s6":4,"s7":3,"s8":5,"s9":5,"s10":5,"s11":5,"s12":5,"s13":4,"b1":4,"b2":4,"b3":4,"b4":4,"b5":4,"b6":3,"b7":3,"b8":4,"b9":4,"b10":4,"b11":4,"b12":4,"b13":4,"b14":2,"b15":4,"b16":2,"b17":4,"b18":2,"b19":3,"b20":4,"b21":4,"b22":4,"b23":5,"b24":4,"b25":4,"b26":4,"b27":4,"b28":5,"b29":2,"b30":4,"b31":3,"b32":4,"b33":4,"b34":4,"b35":4,"b36":4,"b37":4,"b38":2}'::jsonb),
  ('Sean Sutherland', '2026-05-06'::date, 3.92, 3.37, NULL::numeric, NULL::numeric, NULL::numeric, 'Teams of two - Much faster for larger sites.  Or a second hood.', '{"s1":4,"s2":4,"s3":4,"s4":4,"s5":3,"s6":4,"s7":4,"s8":4,"s9":4,"s10":4,"s11":4,"s12":4,"s13":4,"b1":4,"b2":4,"b3":4,"b4":4,"b5":4,"b6":4,"b7":3,"b8":2,"b9":4,"b10":4,"b11":4,"b12":4,"b13":4,"b14":3,"b15":4,"b16":3,"b17":4,"b18":2,"b19":2,"b20":2,"b21":4,"b22":4,"b23":4,"b24":3,"b25":4,"b26":3,"b27":3,"b28":4,"b29":2,"b30":2,"b31":4,"b32":3,"b33":3,"b34":3,"b35":4,"b36":4,"b37":4,"b38":1}'::jsonb)
) AS v(tech_name, assessment_date, safety_avg, basic_avg, intermediate_avg, advanced_avg, survey_avg, comment, raw_scores)
WHERE app_match_technician_id(replace(v.tech_name, '''''', '''')) IS NOT NULL;

-- Verify
SELECT 'dom_rows' AS check_name, t.name, a.date, a.technician_id, a.basic_avg
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE lower(trim(t.name)) = 'dom jean-louis'
ORDER BY a.date DESC;

SELECT 'june_2026_count' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region = 'NE' AND t.deleted_at IS NULL AND a.date >= '2026-06-01';
