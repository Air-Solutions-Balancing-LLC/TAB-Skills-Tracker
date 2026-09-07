-- ATA Manual Resets — admin can add/remove a reset by hand as a backup for when
-- the automatic Teachable/Zapier feed misses a retake.
--
-- Run in Supabase → SQL Editor AFTER supabase/ata-attempts.sql. Safe to re-run.
--
-- How it works:
--   * A manual reset is stored as one row in ata_attempts with source='manual_reset'
--     (score NULL, passed false). It does NOT touch ata_completions, so it never
--     changes a lesson's pass/score — it only bumps the reset counter.
--   * The roster / tech JSON now returns AUTO attempt stats (count, best, last_score,
--     month_count) EXCLUDING manual_reset rows, plus two new fields per lesson:
--       manual_month  — manual resets logged this calendar month
--       manual_total  — manual resets logged all-time
--   * The browser shows:  resets = (auto attempts − 1, min 0) + manual resets.
--     So each "+ reset" click adds exactly one to the displayed count.

-- ── Roster JSON (auto stats exclude manual_reset; expose manual counts) ────────
CREATE OR REPLACE FUNCTION public.app_ata_roster_json(p_region text DEFAULT NULL)
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT json_build_object(
    'techs', coalesce((
      SELECT json_agg(row_to_json(x) ORDER BY x.name)
      FROM (
        SELECT
          t.id, t.name, t.region, t.email,
          (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
             FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
          (SELECT coalesce(json_object_agg(c.lesson_code,
             json_build_object('score', c.score_percent, 'completed_at', c.completed_at, 'passed', c.passed)), '{}'::json)
             FROM ata_completions c WHERE c.tech_id = t.id) AS completions,
          (SELECT coalesce(json_object_agg(s.lesson_code, s.info), '{}'::json) FROM (
             SELECT lesson_code, json_build_object(
               'count', count(*) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
               'best', max(score_percent) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
               'passed', bool_or(coalesce(passed,false)),
               'last_at', max(attempted_at) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
               'last_score', (array_agg(score_percent ORDER BY attempted_at DESC)
                              FILTER (WHERE source IS DISTINCT FROM 'manual_reset'))[1],
               'month_count', count(*) FILTER (WHERE attempted_at >= date_trunc('month', now())
                              AND source IS DISTINCT FROM 'manual_reset'),
               'manual_month', count(*) FILTER (WHERE source = 'manual_reset'
                              AND attempted_at >= date_trunc('month', now())),
               'manual_total', count(*) FILTER (WHERE source = 'manual_reset')
             ) AS info
             FROM ata_attempts WHERE tech_id = t.id GROUP BY lesson_code
          ) s) AS attempts
        FROM technicians t
        WHERE t.deleted_at IS NULL
          AND (p_region IS NULL OR t.region = p_region)
      ) x
    ), '[]'::json),
    'last_import', (
      SELECT row_to_json(l) FROM (
        SELECT ran_at, matched, unmatched, applied
        FROM ata_import_log ORDER BY ran_at DESC LIMIT 1
      ) l
    )
  );
$$;

-- ── Single technician (same auto/manual split) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_tech_data(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_tech    json;
BEGIN
  SELECT s.tech_id INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token AND s.role = 'technician' AND s.expires_at > now();

  IF v_tech_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT row_to_json(x) INTO v_tech
  FROM (
    SELECT
      t.id, t.name, t.region, t.email,
      (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
         FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
      (SELECT coalesce(json_object_agg(c.lesson_code,
         json_build_object('score', c.score_percent, 'completed_at', c.completed_at, 'passed', c.passed)), '{}'::json)
         FROM ata_completions c WHERE c.tech_id = t.id) AS completions,
      (SELECT coalesce(json_object_agg(s.lesson_code, s.info), '{}'::json) FROM (
         SELECT lesson_code, json_build_object(
           'count', count(*) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
           'best', max(score_percent) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
           'passed', bool_or(coalesce(passed,false)),
           'last_at', max(attempted_at) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
           'last_score', (array_agg(score_percent ORDER BY attempted_at DESC)
                          FILTER (WHERE source IS DISTINCT FROM 'manual_reset'))[1],
           'month_count', count(*) FILTER (WHERE attempted_at >= date_trunc('month', now())
                          AND source IS DISTINCT FROM 'manual_reset'),
           'manual_month', count(*) FILTER (WHERE source = 'manual_reset'
                          AND attempted_at >= date_trunc('month', now())),
           'manual_total', count(*) FILTER (WHERE source = 'manual_reset')
         ) AS info
         FROM ata_attempts WHERE tech_id = t.id GROUP BY lesson_code
      ) s) AS attempts
    FROM technicians t
    WHERE t.id = v_tech_id AND t.deleted_at IS NULL
  ) x;

  RETURN v_tech;
END;
$$;

-- ── Write: add a manual reset for one lesson (admin) ──────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_add_reset(p_tech_id bigint, p_lesson_code text, p_reason text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_code  text := upper(trim(coalesce(p_lesson_code,'')));
  v_month int;
  v_total int;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_code !~ 'TAB-[BIA]-[0-9]+' THEN
    RAISE EXCEPTION 'Invalid lesson code';
  END IF;
  v_code := (regexp_match(v_code, '(TAB-[BIA]-[0-9]+)'))[1];
  IF NOT EXISTS (SELECT 1 FROM technicians WHERE id = p_tech_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Unknown technician';
  END IF;

  INSERT INTO ata_attempts (tech_id, lesson_code, score_percent, passed, attempted_at, source, external_id)
  VALUES (p_tech_id, v_code, NULL, false, now(), 'manual_reset',
          'manual-' || replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''));

  SELECT count(*) FILTER (WHERE attempted_at >= date_trunc('month', now())), count(*)
    INTO v_month, v_total
    FROM ata_attempts
   WHERE tech_id = p_tech_id AND lesson_code = v_code AND source = 'manual_reset';

  RETURN json_build_object('ok', true, 'lesson_code', v_code, 'manual_month', v_month, 'manual_total', v_total);
END;
$$;

-- ── Write: remove the most recent manual reset for one lesson (admin) ──────────
CREATE OR REPLACE FUNCTION public.app_ata_remove_reset(p_tech_id bigint, p_lesson_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_code  text := upper(trim(coalesce(p_lesson_code,'')));
  v_month int;
  v_total int;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_code ~ 'TAB-[BIA]-[0-9]+' THEN
    v_code := (regexp_match(v_code, '(TAB-[BIA]-[0-9]+)'))[1];
  END IF;

  DELETE FROM ata_attempts
   WHERE id = (
     SELECT id FROM ata_attempts
      WHERE tech_id = p_tech_id AND lesson_code = v_code AND source = 'manual_reset'
      ORDER BY attempted_at DESC, id DESC
      LIMIT 1
   );

  SELECT count(*) FILTER (WHERE attempted_at >= date_trunc('month', now())), count(*)
    INTO v_month, v_total
    FROM ata_attempts
   WHERE tech_id = p_tech_id AND lesson_code = v_code AND source = 'manual_reset';

  RETURN json_build_object('ok', true, 'lesson_code', v_code, 'manual_month', v_month, 'manual_total', v_total);
END;
$$;

-- ── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.app_ata_roster_json(text)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_tech_data(text)                   TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_add_reset(bigint, text, text)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_remove_reset(bigint, text)        TO authenticated;
