-- Pause an ATA module and shift only the still-open lessons.
-- Run once in Supabase → SQL Editor. Safe to re-run.
--
-- While paused, the technician does not see those lessons as Overdue.
-- Moving due dates keeps passed lessons on their original Thursday and
-- lines the next open lesson up with the coming Thursday.

ALTER TABLE public.ata_completions
  ADD COLUMN IF NOT EXISTS admin_locked boolean NOT NULL DEFAULT false;

ALTER TABLE public.ata_program_starts
  ADD COLUMN IF NOT EXISTS paused boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hold_from_week int,
  ADD COLUMN IF NOT EXISTS hold_weeks int NOT NULL DEFAULT 0;

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
          t.job_position,
          t.start_date,
          t.bootcamp_start_date,
          t.required_categories,
          (t.ata_archived_at IS NOT NULL) AS ata_archived,
          t.ata_archived_at,
          (t.ata_completed_at IS NOT NULL) AS ata_completed,
          t.ata_completed_at,
          (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
             FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
          (SELECT coalesce(json_object_agg(ps.program, json_build_object(
              'paused', coalesce(ps.paused, false),
              'from_week', ps.hold_from_week,
              'weeks', coalesce(ps.hold_weeks, 0)
            )), '{}'::json)
             FROM ata_program_starts ps WHERE ps.tech_id = t.id) AS holds,
          (SELECT coalesce(json_object_agg(c.lesson_code,
             json_build_object(
               'score', c.score_percent,
               'completed_at', c.completed_at,
               'passed', c.passed,
               'admin_locked', coalesce(c.admin_locked, false)
             )), '{}'::json)
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
      t.job_position,
      t.start_date,
      t.bootcamp_start_date,
      t.required_categories,
      (t.ata_archived_at IS NOT NULL) AS ata_archived,
      t.ata_archived_at,
      (t.ata_completed_at IS NOT NULL) AS ata_completed,
      t.ata_completed_at,
      (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
         FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
      (SELECT coalesce(json_object_agg(ps.program, json_build_object(
          'paused', coalesce(ps.paused, false),
          'from_week', ps.hold_from_week,
          'weeks', coalesce(ps.hold_weeks, 0)
        )), '{}'::json)
         FROM ata_program_starts ps WHERE ps.tech_id = t.id) AS holds,
      (SELECT coalesce(json_object_agg(c.lesson_code,
         json_build_object(
           'score', c.score_percent,
           'completed_at', c.completed_at,
           'passed', c.passed,
           'admin_locked', coalesce(c.admin_locked, false)
         )), '{}'::json)
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

CREATE OR REPLACE FUNCTION public.app_ata_set_hold(
  p_tech_id bigint,
  p_program text,
  p_paused boolean,
  p_from_week int,
  p_weeks int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_program NOT IN ('basic','intermediate','advanced') THEN
    RAISE EXCEPTION 'Invalid program';
  END IF;

  UPDATE ata_program_starts
     SET paused = coalesce(p_paused, false),
         hold_from_week = CASE WHEN coalesce(p_weeks, 0) > 0 THEN p_from_week ELSE NULL END,
         hold_weeks = greatest(coalesce(p_weeks, 0), 0),
         updated_at = now()
   WHERE tech_id = p_tech_id
     AND program = p_program;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Set a start date for this module before pausing it';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_roster_json(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_tech_data(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_set_hold(bigint, text, boolean, int, int) TO authenticated;
