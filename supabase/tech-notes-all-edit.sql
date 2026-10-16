-- Allow Notes to Tech and Tech Comments to be edited by Admin, PM (same region),
-- or the technician themselves. Safe to re-run.

DROP FUNCTION IF EXISTS public.app_save_notes_to_tech(bigint, text);

CREATE OR REPLACE FUNCTION public.app_can_edit_tech_notes(p_tech_id bigint, p_token text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_sess_region text;
  v_sess_tech bigint;
BEGIN
  IF p_tech_id IS NULL THEN
    RETURN false;
  END IF;

  IF app_is_admin() THEN
    RETURN true;
  END IF;

  SELECT t.region INTO v_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;

  IF v_region IS NULL THEN
    RETURN false;
  END IF;

  IF p_token IS NULL OR trim(p_token) = '' THEN
    RETURN false;
  END IF;

  SELECT s.tech_id, s.region
    INTO v_sess_tech, v_sess_region
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.expires_at > now();

  IF v_sess_tech IS NOT NULL AND v_sess_tech = p_tech_id THEN
    RETURN true;
  END IF;

  IF v_sess_region IS NOT NULL AND v_sess_region = v_region THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_notes_to_tech(
  p_tech_id bigint,
  p_notes text,
  p_token text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_saved text;
BEGIN
  IF NOT public.app_can_edit_tech_notes(p_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_saved := nullif(trim(p_notes), '');

  UPDATE public.technicians
     SET notes_to_tech = v_saved
   WHERE id = p_tech_id
     AND deleted_at IS NULL
  RETURNING notes_to_tech INTO v_saved;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  RETURN coalesce(v_saved, '');
END;
$$;

-- Keep legacy (token-only) signature working for older clients, and add tech_id form.
CREATE OR REPLACE FUNCTION public.app_save_tech_comments(
  p_token text,
  p_comments text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_saved   text;
BEGIN
  SELECT s.tech_id INTO v_tech_id
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.expires_at > now()
    AND s.tech_id IS NOT NULL;

  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF NOT public.app_can_edit_tech_notes(v_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_saved := nullif(trim(p_comments), '');

  UPDATE public.technicians
     SET tech_comments = v_saved
   WHERE id = v_tech_id
     AND deleted_at IS NULL
  RETURNING tech_comments INTO v_saved;

  RETURN coalesce(v_saved, '');
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_tech_comments_for(
  p_tech_id bigint,
  p_comments text,
  p_token text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_saved text;
BEGIN
  IF NOT public.app_can_edit_tech_notes(p_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_saved := nullif(trim(p_comments), '');

  UPDATE public.technicians
     SET tech_comments = v_saved
   WHERE id = p_tech_id
     AND deleted_at IS NULL
  RETURNING tech_comments INTO v_saved;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  RETURN coalesce(v_saved, '');
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_can_edit_tech_notes(bigint, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_notes_to_tech(bigint, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_tech_comments(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_tech_comments_for(bigint, text, text) TO anon, authenticated;
