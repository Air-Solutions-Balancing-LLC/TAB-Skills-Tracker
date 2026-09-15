-- ATA archive / former techs.
-- Run in Supabase → SQL Editor. Safe to re-run.
--
-- Veterans and people who no longer take digital ATA stay in the company
-- roster (skills, assessments, login). They drop off the default ATA list
-- and the Friday PDF until you restore them.

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS ata_archived_at timestamptz;

-- ── Roster JSON (includes ata_archived; keeps attempt/reset fields) ───────────
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
          (t.ata_archived_at IS NOT NULL) AS ata_archived,
          t.ata_archived_at,
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
      (t.ata_archived_at IS NOT NULL) AS ata_archived,
      t.ata_archived_at,
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

-- Do not invent start dates for archived / former techs.
CREATE OR REPLACE FUNCTION public.app_ata_infer_starts()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_basic int := 0;
  v_inter int := 0;
  v_adv   int := 0;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH firsts AS (
    SELECT tech_id, program, MIN(first_on) AS start_date
    FROM (
      SELECT a.tech_id,
             CASE
               WHEN a.lesson_code LIKE 'TAB-B-%' THEN 'basic'
               WHEN a.lesson_code LIKE 'TAB-I-%' THEN 'intermediate'
               WHEN a.lesson_code LIKE 'TAB-A-%' THEN 'advanced'
             END AS program,
             (a.attempted_at AT TIME ZONE 'America/New_York')::date AS first_on
        FROM ata_attempts a
       WHERE a.source IS DISTINCT FROM 'manual_reset'
         AND a.lesson_code ~ '^TAB-[BIA]-'
      UNION ALL
      SELECT c.tech_id,
             CASE
               WHEN c.lesson_code LIKE 'TAB-B-%' THEN 'basic'
               WHEN c.lesson_code LIKE 'TAB-I-%' THEN 'intermediate'
               WHEN c.lesson_code LIKE 'TAB-A-%' THEN 'advanced'
             END AS program,
             (c.completed_at AT TIME ZONE 'America/New_York')::date AS first_on
        FROM ata_completions c
       WHERE c.completed_at IS NOT NULL
         AND c.lesson_code ~ '^TAB-[BIA]-'
    ) x
    WHERE program IS NOT NULL AND first_on IS NOT NULL
    GROUP BY tech_id, program
  ),
  inserted AS (
    INSERT INTO ata_program_starts (tech_id, program, start_date, updated_at)
    SELECT f.tech_id, f.program, f.start_date, now()
      FROM firsts f
      JOIN technicians t ON t.id = f.tech_id
     WHERE t.deleted_at IS NULL
       AND t.ata_archived_at IS NULL
       AND NOT EXISTS (
         SELECT 1 FROM ata_program_starts s
          WHERE s.tech_id = f.tech_id AND s.program = f.program
       )
    RETURNING program
  )
  SELECT
    count(*) FILTER (WHERE program = 'basic'),
    count(*) FILTER (WHERE program = 'intermediate'),
    count(*) FILTER (WHERE program = 'advanced')
    INTO v_basic, v_inter, v_adv
    FROM inserted;

  RETURN json_build_object(
    'ok', true,
    'basic', v_basic,
    'intermediate', v_inter,
    'advanced', v_adv,
    'filled', v_basic + v_inter + v_adv
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_set_archived(p_tech_ids bigint[], p_archived boolean)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_n int := 0;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_tech_ids IS NULL OR coalesce(array_length(p_tech_ids, 1), 0) = 0 THEN
    RETURN json_build_object('ok', true, 'updated', 0);
  END IF;

  UPDATE technicians
     SET ata_archived_at = CASE
           WHEN p_archived THEN coalesce(ata_archived_at, now())
           ELSE NULL
         END
   WHERE id = ANY (p_tech_ids)
     AND deleted_at IS NULL;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN json_build_object('ok', true, 'updated', v_n);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_roster_json(text)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_tech_data(text)                TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_infer_starts()                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_set_archived(bigint[], boolean) TO authenticated;
