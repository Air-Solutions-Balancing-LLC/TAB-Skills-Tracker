-- Fill empty ATA module start dates from the first Teachable quiz in that module.
-- Does NOT overwrite dates Brenda (or anyone) already typed.
-- Run AFTER supabase/ata-teachable-sync.sql. Safe to re-run.
--
-- Teachable has no "first Friday Brenda assigned". The closest signal is the
-- earliest quiz submission (or completion) for TAB-B / TAB-I / TAB-A.

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
     WHERE NOT EXISTS (
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

GRANT EXECUTE ON FUNCTION public.app_ata_infer_starts() TO authenticated;
