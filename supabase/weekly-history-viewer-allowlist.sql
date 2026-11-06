-- Weekly Evaluations: public share-link history only for designated leads.
-- Allowed viewers (by technician name): Jef/Jeff Tucker, Jimmy Anderson, Kody Collins, Adam Freeman.
-- PMs still use app_weekly_get (full history).
-- Run in Supabase → SQL Editor (safe to re-run).

CREATE OR REPLACE FUNCTION public.app_weekly_norm_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT trim(both ' ' FROM regexp_replace(lower(coalesce(p_name, '')), '[^a-z0-9]+', ' ', 'g'));
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_viewer_can_see_history(p_tech_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.technicians t
    WHERE t.id = p_tech_id
      AND t.deleted_at IS NULL
      AND public.app_weekly_norm_name(t.name) = ANY (ARRAY[
        'jef tucker',
        'jeff tucker',
        'jimmy anderson',
        'kody collins',
        'adam freeman'
      ])
  );
$$;

DROP FUNCTION IF EXISTS public.app_weekly_payload(text);
DROP FUNCTION IF EXISTS public.app_weekly_payload(text, boolean);

CREATE OR REPLACE FUNCTION public.app_weekly_payload(
  p_region text,
  p_include_history boolean DEFAULT true,
  p_exclude_tech_id bigint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result json;
  v_include boolean := coalesce(p_include_history, true);
BEGIN
  SELECT json_build_object(
    'region', p_region,
    'techs', coalesce((
      SELECT json_agg(json_build_object('id', t.id, 'name', t.name) ORDER BY t.name)
      FROM public.technicians t
      WHERE t.deleted_at IS NULL AND t.region = p_region
    ), '[]'::json),
    'roster', coalesce((
      SELECT json_agg(row_to_json(r) ORDER BY r.name)
      FROM (
        SELECT
          t.id AS tech_id,
          t.name,
          CASE
            WHEN v_include THEN coalesce((
              SELECT json_agg(row_to_json(u) ORDER BY u.update_date DESC, u.id DESC)
              FROM (
                SELECT
                  w.id,
                  w.update_date,
                  w.trainer_tech_id,
                  tr.name AS trainer_name,
                  w.trainer_tech_id_2,
                  tr2.name AS trainer_name_2,
                  w.rating_punctuality,
                  w.rating_attitude,
                  w.rating_effort,
                  w.rating_engagement,
                  w.rating_teamwork,
                  w.comment,
                  w.action_plan,
                  w.created_at
                FROM public.weekly_updates w
                LEFT JOIN public.technicians tr ON tr.id = w.trainer_tech_id
                LEFT JOIN public.technicians tr2 ON tr2.id = w.trainer_tech_id_2
                WHERE w.tech_id = t.id AND w.region = p_region
                ORDER BY w.update_date DESC, w.id DESC
              ) u
            ), '[]'::json)
            ELSE '[]'::json
          END AS updates
        FROM public.weekly_update_roster roster
        JOIN public.technicians t ON t.id = roster.tech_id
        WHERE roster.region = p_region
          AND roster.archived_at IS NULL
          AND t.deleted_at IS NULL
          AND (p_exclude_tech_id IS NULL OR t.id IS DISTINCT FROM p_exclude_tech_id)
        ORDER BY t.name
      ) r
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Replace 1-arg public get so anonymous link callers never get history by default.
DROP FUNCTION IF EXISTS public.app_weekly_public_get(text);
DROP FUNCTION IF EXISTS public.app_weekly_public_get(text, bigint);

CREATE OR REPLACE FUNCTION public.app_weekly_public_get(
  p_link_token text,
  p_viewer_tech_id bigint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_include boolean := false;
  v_exclude bigint := NULL;
BEGIN
  SELECT l.region INTO v_region
  FROM public.weekly_update_links l
  WHERE l.token = nullif(trim(p_link_token), '')
  LIMIT 1;

  IF v_region IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired link';
  END IF;

  -- Subjects never see their own evaluation card on the share link.
  IF p_viewer_tech_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.technicians t
      WHERE t.id = p_viewer_tech_id
        AND t.deleted_at IS NULL
        AND t.region = v_region
    ) THEN
      v_exclude := p_viewer_tech_id;
      IF public.app_weekly_viewer_can_see_history(p_viewer_tech_id) THEN
        v_include := true;
      END IF;
    END IF;
  END IF;

  RETURN public.app_weekly_payload(v_region, v_include, v_exclude);
END;
$$;

-- Keep PM get on the 1-arg payload (full history).
CREATE OR REPLACE FUNCTION public.app_weekly_get(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text := app_weekly_session_region(p_token);
BEGIN
  IF v_region IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN app_weekly_payload(v_region, true, NULL);
END;
$$;

-- Block evaluating yourself via the public share link (trainer cannot equal subject).
CREATE OR REPLACE FUNCTION public.app_weekly_add_update(
  p_session_token text,
  p_link_token text,
  p_tech_id bigint,
  p_update_date date,
  p_trainer_tech_id bigint,
  p_comment text,
  p_action_plan text,
  p_trainer_tech_id_2 bigint DEFAULT NULL,
  p_ratings jsonb DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_tech_region text;
  v_punctuality text;
  v_attitude text;
  v_effort text;
  v_engagement text;
  v_teamwork text;
  v_via_link boolean := false;
BEGIN
  IF nullif(trim(coalesce(p_session_token, '')), '') IS NOT NULL THEN
    v_region := app_weekly_session_region(p_session_token);
  END IF;
  IF v_region IS NULL AND nullif(trim(coalesce(p_link_token, '')), '') IS NOT NULL THEN
    SELECT l.region INTO v_region
    FROM public.weekly_update_links l
    WHERE l.token = trim(p_link_token)
    LIMIT 1;
    v_via_link := v_region IS NOT NULL;
  END IF;
  IF v_region IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT t.region INTO v_tech_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;
  IF v_tech_region IS NULL OR v_tech_region IS DISTINCT FROM v_region THEN
    RAISE EXCEPTION 'Technician not in this region';
  END IF;

  -- Share-link: you cannot submit an evaluation on yourself.
  IF v_via_link AND (
       p_trainer_tech_id IS NOT NULL AND p_trainer_tech_id = p_tech_id
    OR p_trainer_tech_id_2 IS NOT NULL AND p_trainer_tech_id_2 = p_tech_id
  ) THEN
    RAISE EXCEPTION 'You cannot submit a Weekly Evaluation for yourself';
  END IF;

  INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
  VALUES (v_region, p_tech_id, NULL)
  ON CONFLICT (region, tech_id) DO UPDATE
    SET archived_at = NULL;

  IF p_trainer_tech_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.technicians t
      WHERE t.id = p_trainer_tech_id AND t.deleted_at IS NULL AND t.region = v_region
    ) THEN
      RAISE EXCEPTION 'Training tech not in this region';
    END IF;
  END IF;

  IF p_trainer_tech_id_2 IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.technicians t
      WHERE t.id = p_trainer_tech_id_2 AND t.deleted_at IS NULL AND t.region = v_region
    ) THEN
      RAISE EXCEPTION 'Second training tech not in this region';
    END IF;
  END IF;

  v_punctuality := app_weekly_norm_su(p_ratings->>'punctuality');
  v_attitude := app_weekly_norm_su(p_ratings->>'attitude');
  v_effort := app_weekly_norm_su(p_ratings->>'effort');
  v_engagement := app_weekly_norm_su(p_ratings->>'engagement');
  v_teamwork := app_weekly_norm_su(p_ratings->>'teamwork');

  IF v_punctuality IS NULL OR v_attitude IS NULL OR v_effort IS NULL
     OR v_engagement IS NULL OR v_teamwork IS NULL THEN
    RAISE EXCEPTION 'Rate Punctuality, Attitude, Effort Level, Engagement, and Teamwork (S or U)';
  END IF;

  INSERT INTO public.weekly_updates (
    region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
    rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
    comment, action_plan
  )
  VALUES (
    v_region,
    p_tech_id,
    coalesce(p_update_date, (now() AT TIME ZONE 'America/New_York')::date),
    p_trainer_tech_id,
    p_trainer_tech_id_2,
    v_punctuality,
    v_attitude,
    v_effort,
    v_engagement,
    v_teamwork,
    nullif(trim(coalesce(p_comment, '')), ''),
    nullif(trim(coalesce(p_action_plan, '')), '')
  );

  -- Public link responses omit history unless caller reloads with an allowlisted viewer.
  IF v_via_link THEN
    RETURN app_weekly_payload(v_region, false, NULL);
  END IF;
  RETURN app_weekly_payload(v_region, true, NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_weekly_norm_name(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_viewer_can_see_history(bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_payload(text, boolean, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_get(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_public_get(text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_add_update(text, text, bigint, date, bigint, text, text, bigint, jsonb) TO anon, authenticated;
