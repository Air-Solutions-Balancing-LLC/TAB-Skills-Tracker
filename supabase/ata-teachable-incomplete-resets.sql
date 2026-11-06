-- Detect Teachable Fail → Incomplete as a quiz reset.
--
-- When ATA still has a failing score (<80%) for a lesson, but the latest
-- Teachable sync no longer has a graded response for that tech/lesson
-- (quiz was reset to Incomplete), insert one manual_reset attempt so the
-- app shows Status "Reset" and bumps the Resets column (0/3 → 1/3).
--
-- Manage resets (+ reset) still works the same way.
--
-- Run once in Supabase → SQL Editor AFTER ata-attempts.sql / ata-teachable-sync.sql.
-- Safe to re-run. Called by Netlify ata-teachable-sync after score ingest.

CREATE OR REPLACE FUNCTION public.app_ata_detect_teachable_resets(
  p_secret text,
  p_present jsonb,
  p_synced_lessons jsonb DEFAULT '[]'::jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret   text;
  v_inserted int := 0;
  v_skipped  int := 0;
  v_cand     int := 0;
  v_rows     int;
  r          record;
  v_last_g   timestamptz;
  v_last_r   timestamptz;
  v_ext      text;
  v_stamp    text;
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  IF p_present IS NULL OR jsonb_typeof(p_present) <> 'array' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_present');
  END IF;

  IF p_synced_lessons IS NULL OR jsonb_typeof(p_synced_lessons) <> 'array'
     OR jsonb_array_length(p_synced_lessons) = 0 THEN
    RETURN json_build_object('ok', true, 'inserted', 0, 'skipped', 0, 'candidates', 0,
                             'note', 'no_synced_lessons');
  END IF;

  DROP TABLE IF EXISTS _ata_sync_present;
  CREATE TEMP TABLE _ata_sync_present (
    tech_id bigint NOT NULL,
    lesson_code text NOT NULL,
    PRIMARY KEY (tech_id, lesson_code)
  ) ON COMMIT DROP;

  DROP TABLE IF EXISTS _ata_sync_lessons;
  CREATE TEMP TABLE _ata_sync_lessons (
    lesson_code text PRIMARY KEY
  ) ON COMMIT DROP;

  INSERT INTO _ata_sync_lessons (lesson_code)
  SELECT DISTINCT upper(trim(value #>> '{}'))
  FROM jsonb_array_elements(p_synced_lessons)
  WHERE upper(trim(value #>> '{}')) ~ '^TAB-[BIA]-[0-9]+$'
  ON CONFLICT DO NOTHING;

  -- Map currently graded Teachable rows → technician ids
  INSERT INTO _ata_sync_present (tech_id, lesson_code)
  SELECT DISTINCT t.id, upper(trim(x.lesson_code))
  FROM jsonb_to_recordset(p_present) AS x(email text, name text, lesson_code text)
  JOIN public.technicians t ON t.deleted_at IS NULL
    AND (
      (nullif(lower(trim(coalesce(x.email,''))), '') IS NOT NULL
        AND t.email IS NOT NULL
        AND lower(trim(t.email)) = lower(trim(x.email)))
      OR (nullif(lower(trim(coalesce(x.name,''))), '') IS NOT NULL
        AND lower(trim(t.name)) = lower(trim(x.name)))
    )
  WHERE upper(trim(coalesce(x.lesson_code,''))) ~ '^TAB-[BIA]-[0-9]+$'
  ON CONFLICT DO NOTHING;

  FOR r IN
    SELECT c.tech_id, c.lesson_code, c.score_percent
    FROM public.ata_completions c
    JOIN public.technicians t ON t.id = c.tech_id AND t.deleted_at IS NULL
    JOIN _ata_sync_lessons sl ON sl.lesson_code = c.lesson_code
    WHERE coalesce(c.passed, false) = false
      AND c.score_percent IS NOT NULL
      AND c.score_percent < 80
      AND NOT EXISTS (
        SELECT 1 FROM _ata_sync_present p
        WHERE p.tech_id = c.tech_id AND p.lesson_code = c.lesson_code
      )
  LOOP
    v_cand := v_cand + 1;

    SELECT max(a.attempted_at) INTO v_last_g
    FROM public.ata_attempts a
    WHERE a.tech_id = r.tech_id
      AND a.lesson_code = r.lesson_code
      AND a.source IS DISTINCT FROM 'manual_reset'
      AND a.score_percent IS NOT NULL;

    SELECT max(a.attempted_at) INTO v_last_r
    FROM public.ata_attempts a
    WHERE a.tech_id = r.tech_id
      AND a.lesson_code = r.lesson_code
      AND a.source = 'manual_reset';

    -- Already have a reset at/after the latest graded fail → still Incomplete; skip.
    IF v_last_r IS NOT NULL AND (v_last_g IS NULL OR v_last_r >= v_last_g) THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    v_stamp := to_char(coalesce(v_last_g, now()), 'YYYYMMDDHH24MISSMS');
    v_ext := 'teachable-incomplete:' || r.tech_id || ':' || r.lesson_code || ':' || v_stamp;

    INSERT INTO public.ata_attempts (
      tech_id, lesson_code, score_percent, passed, attempted_at, source, external_id
    ) VALUES (
      r.tech_id, r.lesson_code, NULL, false, now(), 'manual_reset', v_ext
    )
    ON CONFLICT (external_id) WHERE external_id IS NOT NULL DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows > 0 THEN
      v_inserted := v_inserted + 1;
    ELSE
      v_skipped := v_skipped + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'ok', true,
    'inserted', v_inserted,
    'skipped', v_skipped,
    'candidates', v_cand
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_detect_teachable_resets(text, jsonb, jsonb) TO anon, authenticated;
