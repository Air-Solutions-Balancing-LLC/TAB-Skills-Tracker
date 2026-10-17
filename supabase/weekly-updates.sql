-- Weekly Updates (PM roster + training-tech share links)
-- Run in Supabase → SQL Editor (safe to re-run).
-- Supports: soft-archive roster, second training tech on each update.

CREATE TABLE IF NOT EXISTS public.weekly_update_links (
  region text PRIMARY KEY,
  token text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.weekly_update_roster (
  id bigserial PRIMARY KEY,
  region text NOT NULL,
  tech_id bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (region, tech_id)
);

CREATE TABLE IF NOT EXISTS public.weekly_updates (
  id bigserial PRIMARY KEY,
  region text NOT NULL,
  tech_id bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  update_date date NOT NULL DEFAULT ((now() AT TIME ZONE 'America/New_York')::date),
  trainer_tech_id bigint REFERENCES public.technicians(id) ON DELETE SET NULL,
  comment text,
  action_plan text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.weekly_update_roster
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

ALTER TABLE public.weekly_updates
  ADD COLUMN IF NOT EXISTS trainer_tech_id_2 bigint REFERENCES public.technicians(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS weekly_updates_tech_date_idx
  ON public.weekly_updates (tech_id, update_date DESC, id DESC);
CREATE INDEX IF NOT EXISTS weekly_updates_region_idx
  ON public.weekly_updates (region);
CREATE INDEX IF NOT EXISTS weekly_update_roster_active_idx
  ON public.weekly_update_roster (region)
  WHERE archived_at IS NULL;

CREATE OR REPLACE FUNCTION public.app_weekly_session_region(p_token text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT s.region
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.expires_at > now()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_ensure_link(p_token text, p_region text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_token text;
  v_sess text := app_weekly_session_region(p_token);
BEGIN
  -- Valid PM/admin session can mint share links for any region (link token is the secret).
  IF v_sess IS NULL THEN
    BEGIN
      IF NOT app_is_admin() THEN
        RAISE EXCEPTION 'Not authorized';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Not authorized';
    END;
  END IF;

  v_region := nullif(trim(coalesce(p_region, '')), '');
  IF v_region IS NULL THEN
    v_region := v_sess;
  END IF;

  IF v_region IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT l.token INTO v_token
  FROM public.weekly_update_links l
  WHERE l.region = v_region;

  IF v_token IS NULL THEN
    v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
    INSERT INTO public.weekly_update_links (region, token)
    VALUES (v_region, v_token)
    ON CONFLICT (region) DO NOTHING;
    SELECT l.token INTO v_token
    FROM public.weekly_update_links l
    WHERE l.region = v_region;
  END IF;

  RETURN json_build_object('region', v_region, 'token', v_token);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_payload(p_region text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result json;
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
          coalesce((
            SELECT json_agg(row_to_json(u) ORDER BY u.update_date DESC, u.id DESC)
            FROM (
              SELECT
                w.id,
                w.update_date,
                w.trainer_tech_id,
                tr.name AS trainer_name,
                w.trainer_tech_id_2,
                tr2.name AS trainer_name_2,
                w.comment,
                w.action_plan,
                w.created_at
              FROM public.weekly_updates w
              LEFT JOIN public.technicians tr ON tr.id = w.trainer_tech_id
              LEFT JOIN public.technicians tr2 ON tr2.id = w.trainer_tech_id_2
              WHERE w.tech_id = t.id AND w.region = p_region
              ORDER BY w.update_date DESC, w.id DESC
            ) u
          ), '[]'::json) AS updates
        FROM public.weekly_update_roster roster
        JOIN public.technicians t ON t.id = roster.tech_id
        WHERE roster.region = p_region
          AND roster.archived_at IS NULL
          AND t.deleted_at IS NULL
        ORDER BY t.name
      ) r
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

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
  RETURN app_weekly_payload(v_region);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_public_get(p_link_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
BEGIN
  SELECT l.region INTO v_region
  FROM public.weekly_update_links l
  WHERE l.token = nullif(trim(p_link_token), '')
  LIMIT 1;

  IF v_region IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired link';
  END IF;

  RETURN app_weekly_payload(v_region);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_add_tech(p_token text, p_tech_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text := app_weekly_session_region(p_token);
  v_tech_region text;
BEGIN
  IF v_region IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT t.region INTO v_tech_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;
  IF v_tech_region IS NULL OR v_tech_region IS DISTINCT FROM v_region THEN
    RAISE EXCEPTION 'Technician not in this region';
  END IF;
  INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
  VALUES (v_region, p_tech_id, NULL)
  ON CONFLICT (region, tech_id) DO UPDATE
    SET archived_at = NULL;
  RETURN app_weekly_payload(v_region);
END;
$$;

-- Soft-archive (was hard-delete). Keeps update history; tech can be restored via Add.
CREATE OR REPLACE FUNCTION public.app_weekly_remove_tech(p_token text, p_tech_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text := app_weekly_session_region(p_token);
BEGIN
  IF v_region IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.weekly_update_roster
  SET archived_at = coalesce(archived_at, now())
  WHERE region = v_region AND tech_id = p_tech_id;
  RETURN app_weekly_payload(v_region);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_public_add_tech(p_link_token text, p_tech_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_tech_region text;
BEGIN
  SELECT l.region INTO v_region
  FROM public.weekly_update_links l
  WHERE l.token = nullif(trim(p_link_token), '')
  LIMIT 1;
  IF v_region IS NULL THEN RAISE EXCEPTION 'Invalid or expired link'; END IF;

  SELECT t.region INTO v_tech_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;
  IF v_tech_region IS NULL OR v_tech_region IS DISTINCT FROM v_region THEN
    RAISE EXCEPTION 'Technician not in this region';
  END IF;

  INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
  VALUES (v_region, p_tech_id, NULL)
  ON CONFLICT (region, tech_id) DO UPDATE
    SET archived_at = NULL;
  RETURN app_weekly_payload(v_region);
END;
$$;

DROP FUNCTION IF EXISTS public.app_weekly_add_update(text, text, bigint, date, bigint, text, text);
DROP FUNCTION IF EXISTS public.app_weekly_add_update(text, text, bigint, date, bigint, text, text, bigint);

CREATE OR REPLACE FUNCTION public.app_weekly_add_update(
  p_session_token text,
  p_link_token text,
  p_tech_id bigint,
  p_update_date date,
  p_trainer_tech_id bigint,
  p_comment text,
  p_action_plan text,
  p_trainer_tech_id_2 bigint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_tech_region text;
BEGIN
  IF nullif(trim(coalesce(p_session_token, '')), '') IS NOT NULL THEN
    v_region := app_weekly_session_region(p_session_token);
  END IF;
  IF v_region IS NULL AND nullif(trim(coalesce(p_link_token, '')), '') IS NOT NULL THEN
    SELECT l.region INTO v_region
    FROM public.weekly_update_links l
    WHERE l.token = trim(p_link_token)
    LIMIT 1;
  END IF;
  IF v_region IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT t.region INTO v_tech_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;
  IF v_tech_region IS NULL OR v_tech_region IS DISTINCT FROM v_region THEN
    RAISE EXCEPTION 'Technician not in this region';
  END IF;

  -- Auto-enroll / restore on first update from share link.
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

  INSERT INTO public.weekly_updates (
    region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2, comment, action_plan
  )
  VALUES (
    v_region,
    p_tech_id,
    coalesce(p_update_date, (now() AT TIME ZONE 'America/New_York')::date),
    p_trainer_tech_id,
    p_trainer_tech_id_2,
    nullif(trim(coalesce(p_comment, '')), ''),
    nullif(trim(coalesce(p_action_plan, '')), '')
  );

  RETURN app_weekly_payload(v_region);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_weekly_delete_update(
  p_session_token text,
  p_link_token text,
  p_update_id bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_row_region text;
BEGIN
  IF nullif(trim(coalesce(p_session_token, '')), '') IS NOT NULL THEN
    v_region := app_weekly_session_region(p_session_token);
  END IF;
  IF v_region IS NULL AND nullif(trim(coalesce(p_link_token, '')), '') IS NOT NULL THEN
    SELECT l.region INTO v_region
    FROM public.weekly_update_links l
    WHERE l.token = trim(p_link_token)
    LIMIT 1;
  END IF;
  IF v_region IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT w.region INTO v_row_region
  FROM public.weekly_updates w
  WHERE w.id = p_update_id;
  IF v_row_region IS NULL OR v_row_region IS DISTINCT FROM v_region THEN
    RAISE EXCEPTION 'Update not found';
  END IF;

  DELETE FROM public.weekly_updates WHERE id = p_update_id;
  RETURN app_weekly_payload(v_region);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_weekly_session_region(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_ensure_link(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_payload(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_get(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_public_get(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_add_tech(text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_remove_tech(text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_public_add_tech(text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_add_update(text, text, bigint, date, bigint, text, text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_weekly_delete_update(text, text, bigint) TO anon, authenticated;
