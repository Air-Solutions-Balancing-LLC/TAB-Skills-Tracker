-- ATA Teachable sync — batch ingest of quiz attempts from the Teachable API.
-- Run in Supabase → SQL Editor AFTER supabase/ata-attempts.sql. Safe to re-run.
--
-- Used by the Netlify function ata-teachable-sync (daily + admin button).
-- Each row is idempotent on p_external_id (same Teachable response is not
-- double-counted). A later attempt with a new submitted_at becomes a new reset.

CREATE OR REPLACE FUNCTION public.app_ata_import_attempts(p_secret text, p_rows jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret  text;
  r         jsonb;
  v_email   text;
  v_name    text;
  v_code    text;
  v_tid     bigint;
  v_score   numeric;
  v_passed  boolean;
  v_at      timestamptz;
  v_ext     text;
  v_applied int := 0;
  v_matched int := 0;
  v_unmatch int := 0;
  v_seen    text[] := ARRAY[]::text[];
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_rows');
  END IF;

  FOR r IN SELECT value FROM jsonb_array_elements(p_rows)
  LOOP
    v_email := lower(trim(coalesce(r->>'email', r->>'source_email', '')));
    v_name  := lower(trim(coalesce(r->>'name', '')));
    v_code  := upper(trim(coalesce(r->>'lesson_code', '')));
    v_ext   := nullif(trim(coalesce(r->>'external_id', '')), '');
    v_at    := coalesce((r->>'attempted_at')::timestamptz, (r->>'completed_at')::timestamptz, now());
    v_tid   := NULL;

    IF v_code ~ 'TAB-[BIA]-[0-9]+' THEN
      v_code := (regexp_match(v_code, '(TAB-[BIA]-[0-9]+)'))[1];
    ELSE
      CONTINUE;
    END IF;

    IF r ? 'score' AND nullif(r->>'score','') IS NOT NULL THEN
      v_score := (r->>'score')::numeric;
      IF v_score <= 1 AND v_score > 0 THEN
        v_score := v_score * 100;
      END IF;
    ELSE
      v_score := NULL;
    END IF;
    v_passed := v_score IS NOT NULL AND v_score >= 80;

    IF v_email <> '' THEN
      SELECT id INTO v_tid FROM technicians
       WHERE email IS NOT NULL AND lower(trim(email)) = v_email AND deleted_at IS NULL
       LIMIT 1;
    END IF;
    IF v_tid IS NULL AND v_name <> '' THEN
      SELECT id INTO v_tid FROM technicians
       WHERE lower(trim(name)) = v_name AND deleted_at IS NULL
       LIMIT 1;
    END IF;

    IF v_tid IS NULL THEN
      v_unmatch := v_unmatch + 1;
      CONTINUE;
    END IF;

    IF NOT (v_tid::text = ANY (v_seen)) THEN
      v_seen := array_append(v_seen, v_tid::text);
      v_matched := v_matched + 1;
    END IF;

    INSERT INTO ata_attempts (tech_id, lesson_code, score_percent, passed, attempted_at, source, external_id)
    VALUES (v_tid, v_code, v_score, v_passed, v_at, 'teachable', v_ext)
    ON CONFLICT (external_id) WHERE external_id IS NOT NULL DO UPDATE
      SET tech_id = EXCLUDED.tech_id,
          lesson_code = EXCLUDED.lesson_code,
          score_percent = EXCLUDED.score_percent,
          passed = EXCLUDED.passed,
          attempted_at = EXCLUDED.attempted_at,
          source = EXCLUDED.source;

    INSERT INTO ata_completions (tech_id, lesson_code, score_percent, completed_at, passed, source_email, updated_at)
    VALUES (v_tid, v_code, v_score, CASE WHEN v_passed THEN v_at END, v_passed, nullif(v_email,''), now())
    ON CONFLICT (tech_id, lesson_code) DO UPDATE
      SET score_percent = GREATEST(coalesce(ata_completions.score_percent, 0), coalesce(EXCLUDED.score_percent, 0)),
          passed        = ata_completions.passed OR EXCLUDED.passed,
          completed_at  = coalesce(ata_completions.completed_at, EXCLUDED.completed_at),
          source_email  = coalesce(EXCLUDED.source_email, ata_completions.source_email),
          updated_at    = now();

    v_applied := v_applied + 1;
  END LOOP;

  INSERT INTO ata_import_log (matched, unmatched, applied)
  VALUES (v_matched, v_unmatch, v_applied);

  RETURN json_build_object(
    'ok', true,
    'applied', v_applied,
    'matched', v_matched,
    'unmatched', v_unmatch
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_import_attempts(text, jsonb) TO anon, authenticated;
