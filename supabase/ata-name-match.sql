-- Fix technician matching for ATA imports (sheet + Zapier).
-- Run in Supabase → SQL Editor.
--
-- Problem: Google Sheet tabs use nicknames (e.g. "Cam Smith") while the
-- technicians table has the full name ("Cameron Smith"), so exact-name
-- matching left completions unmatched and the UI showed 0/N overdue.
--
-- Fix: after email + exact name, try a safe nickname match:
--   same last name AND one first name is a prefix of the other
--   (only when exactly one technician matches).

CREATE OR REPLACE FUNCTION public.app_ata_match_tech(p_email text, p_name text)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email text := lower(trim(coalesce(p_email,'')));
  v_name  text := lower(trim(coalesce(p_name,'')));
  v_tid   bigint;
  v_first text;
  v_last  text;
BEGIN
  IF v_email <> '' THEN
    SELECT id INTO v_tid FROM technicians
    WHERE email IS NOT NULL AND lower(trim(email)) = v_email AND deleted_at IS NULL
    LIMIT 1;
    IF v_tid IS NOT NULL THEN RETURN v_tid; END IF;
  END IF;

  IF v_name = '' THEN RETURN NULL; END IF;

  SELECT id INTO v_tid FROM technicians
  WHERE lower(trim(name)) = v_name AND deleted_at IS NULL
  LIMIT 1;
  IF v_tid IS NOT NULL THEN RETURN v_tid; END IF;

  -- Nickname / short-name match: "cam smith" ↔ "cameron smith"
  v_first := split_part(v_name, ' ', 1);
  v_last  := regexp_replace(v_name, '^.*\s+', '');
  IF v_first = '' OR v_last = '' OR v_first = v_last THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_tid
  FROM technicians
  WHERE deleted_at IS NULL
    AND lower(trim(regexp_replace(name, '^.*\s+', ''))) = v_last
    AND (
      lower(trim(split_part(name, ' ', 1))) LIKE v_first || '%'
      OR v_first LIKE lower(trim(split_part(name, ' ', 1))) || '%'
    )
  LIMIT 2;

  -- Only accept when exactly one technician matches (avoid wrong person).
  IF (SELECT count(*) FROM technicians
      WHERE deleted_at IS NULL
        AND lower(trim(regexp_replace(name, '^.*\s+', ''))) = v_last
        AND (
          lower(trim(split_part(name, ' ', 1))) LIKE v_first || '%'
          OR v_first LIKE lower(trim(split_part(name, ' ', 1))) || '%'
        )) = 1 THEN
    RETURN v_tid;
  END IF;

  RETURN NULL;
END;
$$;

-- Refresh sheet-import RPC to use the matcher + set passed (>=80%).
CREATE OR REPLACE FUNCTION public.app_ata_import(p_rows jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  rec          record;
  v_email      text;
  v_name       text;
  v_code       text;
  v_tid        bigint;
  v_matched    int := 0;
  v_unmatched  int := 0;
  v_applied    int := 0;
  v_rowcount   int;
  v_key        text;
  v_passed     boolean;
  v_unmatched_names text[] := ARRAY[]::text[];
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  FOR rec IN
    SELECT *
    FROM jsonb_to_recordset(coalesce(p_rows, '[]'::jsonb))
      AS x(name text, email text, lesson_code text, score numeric, completed_at timestamptz)
  LOOP
    v_email := lower(trim(coalesce(rec.email, '')));
    v_name  := lower(trim(coalesce(rec.name, '')));
    v_code  := upper(trim(coalesce(rec.lesson_code, '')));

    IF v_code !~ 'TAB-[BIA]-[0-9]+' THEN
      CONTINUE;
    END IF;
    v_code := (regexp_match(v_code, '(TAB-[BIA]-[0-9]+)'))[1];

    IF v_email = '' AND v_name = '' THEN
      CONTINUE;
    END IF;

    v_tid := app_ata_match_tech(v_email, v_name);

    IF v_tid IS NULL THEN
      v_unmatched := v_unmatched + 1;
      v_key := coalesce(nullif(v_name, ''), v_email);
      IF NOT (v_key = ANY(v_unmatched_names)) AND coalesce(array_length(v_unmatched_names,1),0) < 50 THEN
        v_unmatched_names := array_append(v_unmatched_names, v_key);
      END IF;
      CONTINUE;
    END IF;

    v_matched := v_matched + 1;
    v_passed := rec.score IS NULL OR rec.score >= 80;

    INSERT INTO ata_completions (tech_id, lesson_code, score_percent, completed_at, passed, source_email, updated_at)
    VALUES (v_tid, v_code, rec.score, rec.completed_at, v_passed, nullif(v_email,''), now())
    ON CONFLICT (tech_id, lesson_code) DO UPDATE
      SET score_percent = EXCLUDED.score_percent,
          completed_at  = EXCLUDED.completed_at,
          passed        = EXCLUDED.passed,
          source_email  = EXCLUDED.source_email,
          updated_at    = now()
      WHERE EXCLUDED.completed_at IS NULL
         OR ata_completions.completed_at IS NULL
         OR EXCLUDED.completed_at >= ata_completions.completed_at;

    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    v_applied := v_applied + v_rowcount;
  END LOOP;

  INSERT INTO ata_import_log (matched, unmatched, applied)
  VALUES (v_matched, v_unmatched, v_applied);

  RETURN json_build_object(
    'matched', v_matched,
    'unmatched', v_unmatched,
    'applied', v_applied,
    'unmatched_names', to_json(v_unmatched_names)
  );
END;
$$;

-- Refresh Zapier endpoint to use the same matcher.
CREATE OR REPLACE FUNCTION public.app_ata_record_attempt(
  p_secret       text,
  p_email        text DEFAULT NULL,
  p_name         text DEFAULT NULL,
  p_lesson_code  text DEFAULT NULL,
  p_score        numeric DEFAULT NULL,
  p_correct      numeric DEFAULT NULL,
  p_total        numeric DEFAULT NULL,
  p_attempted_at timestamptz DEFAULT NULL,
  p_external_id  text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret  text;
  v_email   text := lower(trim(coalesce(p_email,'')));
  v_name    text := lower(trim(coalesce(p_name,'')));
  v_code    text := upper(trim(coalesce(p_lesson_code,'')));
  v_tid     bigint;
  v_score   numeric;
  v_passed  boolean;
  v_at      timestamptz := coalesce(p_attempted_at, now());
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  IF v_code !~ 'TAB-[BIA]-[0-9]+' THEN
    RETURN json_build_object('ok', false, 'error', 'no_lesson_code');
  END IF;
  v_code := (regexp_match(v_code, '(TAB-[BIA]-[0-9]+)'))[1];

  IF p_score IS NOT NULL THEN
    v_score := CASE WHEN p_score <= 1 AND p_score > 0 THEN p_score * 100 ELSE p_score END;
  ELSIF p_total IS NOT NULL AND p_total > 0 THEN
    v_score := round((coalesce(p_correct,0) / p_total) * 1000) / 10;
  ELSE
    v_score := NULL;
  END IF;
  v_passed := v_score IS NOT NULL AND v_score >= 80;

  v_tid := app_ata_match_tech(v_email, v_name);
  IF v_tid IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'no_tech', 'email', v_email, 'name', v_name);
  END IF;

  INSERT INTO ata_attempts (tech_id, lesson_code, score_percent, passed, attempted_at, source, external_id)
  VALUES (v_tid, v_code, v_score, v_passed, v_at, 'zapier', nullif(p_external_id,''))
  ON CONFLICT (external_id) WHERE external_id IS NOT NULL DO UPDATE
    SET tech_id = EXCLUDED.tech_id,
        lesson_code = EXCLUDED.lesson_code,
        score_percent = EXCLUDED.score_percent,
        passed = EXCLUDED.passed,
        attempted_at = EXCLUDED.attempted_at;

  INSERT INTO ata_completions (tech_id, lesson_code, score_percent, completed_at, passed, source_email, updated_at)
  VALUES (v_tid, v_code, v_score, CASE WHEN v_passed THEN v_at END, v_passed, nullif(v_email,''), now())
  ON CONFLICT (tech_id, lesson_code) DO UPDATE
    SET score_percent = GREATEST(coalesce(ata_completions.score_percent, 0), coalesce(EXCLUDED.score_percent, 0)),
        passed        = ata_completions.passed OR EXCLUDED.passed,
        completed_at  = coalesce(ata_completions.completed_at, EXCLUDED.completed_at),
        source_email  = coalesce(EXCLUDED.source_email, ata_completions.source_email),
        updated_at    = now();

  RETURN json_build_object('ok', true, 'tech_id', v_tid, 'lesson_code', v_code, 'score', v_score, 'passed', v_passed);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_match_tech(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_import(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_record_attempt(text,text,text,text,numeric,numeric,numeric,timestamptz,text) TO anon, authenticated;
