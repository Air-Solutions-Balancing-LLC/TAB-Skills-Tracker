-- ATA categories: Active / Complete / Exempt
-- Run in Supabase → SQL Editor. Safe to re-run.
--
-- Exempt  = ata_archived_at set (not on weekly reports)
-- Complete = ata_completed_at set OR all three programs passed (not on weekly reports)
-- Active  = neither (shown on weekly reports)

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS ata_archived_at timestamptz;

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS ata_completed_at timestamptz;

-- ── Set category from admin edit card / ATA roster ───────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_set_category(p_tech_id bigint, p_category text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_cat text := lower(trim(coalesce(p_category, 'active')));
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_tech_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_tech');
  END IF;
  IF v_cat NOT IN ('active', 'complete', 'exempt') THEN
    RETURN json_build_object('ok', false, 'error', 'bad_category');
  END IF;

  UPDATE public.technicians
     SET ata_archived_at = CASE
           WHEN v_cat = 'exempt' THEN coalesce(ata_archived_at, now())
           ELSE NULL
         END,
         ata_completed_at = CASE
           WHEN v_cat = 'complete' THEN coalesce(ata_completed_at, now())
           ELSE NULL
         END
   WHERE id = p_tech_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'not_found');
  END IF;
  RETURN json_build_object('ok', true, 'category', v_cat);
END;
$$;

-- Keep Mark Exempt / Restore working; clear completed when exempting.
CREATE OR REPLACE FUNCTION public.app_ata_set_archived(p_tech_id bigint, p_archived boolean)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_tech_id IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_tech');
  END IF;

  IF p_archived THEN
    RETURN public.app_ata_set_category(p_tech_id, 'exempt');
  END IF;

  UPDATE public.technicians
     SET ata_archived_at = NULL
   WHERE id = p_tech_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'error', 'not_found');
  END IF;
  RETURN json_build_object('ok', true, 'category', 'active');
END;
$$;

-- ── Roster + tech self data include completed flag ───────────────────────────
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
          (t.ata_completed_at IS NOT NULL) AS ata_completed,
          t.ata_completed_at,
          (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
             FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
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
      (t.ata_archived_at IS NOT NULL) AS ata_archived,
      t.ata_archived_at,
      (t.ata_completed_at IS NOT NULL) AS ata_completed,
      t.ata_completed_at,
      (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
         FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
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

-- ── Admin people list: ATA status fields for edit card ───────────────────────
DROP FUNCTION IF EXISTS public.app_admin_list_people();

CREATE OR REPLACE FUNCTION public.app_admin_list_people()
RETURNS TABLE (
  id bigint,
  email text,
  full_name text,
  role text,
  region text,
  deleted boolean,
  tech_id bigint,
  nebb_status text,
  cert_expires_on date,
  cecs_complete boolean,
  nebb_site_updated boolean,
  start_date date,
  bootcamp_start_date date,
  latest_raw_scores jsonb,
  required_categories jsonb,
  training_focus text,
  training_goal_start date,
  training_goal_end date,
  job_position text,
  ata_archived boolean,
  ata_archived_at timestamptz,
  ata_completed boolean,
  ata_completed_at timestamptz
)
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
           CASE WHEN p.role='technician' THEN t.region ELSE p.region END AS region,
           (t.deleted_at IS NOT NULL) AS deleted,
           p.tech_id,
           CASE WHEN p.role='technician' THEN t.nebb_status ELSE p.nebb_status END AS nebb_status,
           CASE WHEN p.role='technician' THEN t.cert_expires_on ELSE p.cert_expires_on END AS cert_expires_on,
           CASE WHEN p.role='technician' THEN coalesce(t.cecs_complete,false) ELSE coalesce(p.cecs_complete,false) END AS cecs_complete,
           CASE WHEN p.role='technician' THEN coalesce(t.nebb_site_updated,false) ELSE coalesce(p.nebb_site_updated,false) END AS nebb_site_updated,
           t.start_date,
           t.bootcamp_start_date,
           (
             SELECT a.raw_scores::jsonb
             FROM public.assessments a
             WHERE %s
               AND a.raw_scores IS NOT NULL
               AND a.raw_scores::jsonb <> '{}'::jsonb
             ORDER BY a.date DESC
             LIMIT 1
           ) AS latest_raw_scores,
           t.required_categories,
           t.training_focus,
           t.training_goal_start,
           t.training_goal_end,
           t.job_position,
           (t.ata_archived_at IS NOT NULL) AS ata_archived,
           t.ata_archived_at,
           (t.ata_completed_at IS NOT NULL) AS ata_completed,
           t.ata_completed_at
    FROM public.app_people p
    LEFT JOIN public.technicians t ON t.id = p.tech_id
    ORDER BY
      CASE p.role WHEN 'admin' THEN 1 WHEN 'pm' THEN 2 ELSE 3 END,
      (t.deleted_at IS NOT NULL),
      lower(COALESCE(p.full_name, t.name, p.email))
  $q$, v_join);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_set_category(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_set_archived(bigint, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_roster_json(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_tech_data(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_people() TO authenticated;
