-- Technician notes: PM/admin → tech, and tech → self comments
-- Run in Supabase -> SQL Editor (safe to re-run).

ALTER TABLE public.technicians ADD COLUMN IF NOT EXISTS notes_to_tech text;
ALTER TABLE public.technicians ADD COLUMN IF NOT EXISTS tech_comments text;

-- Technician saves their own comments (technician session token).
CREATE OR REPLACE FUNCTION public.app_save_tech_comments(p_token text, p_comments text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_saved   text;
BEGIN
  SELECT s.tech_id
  INTO v_tech_id
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.role = 'technician'
    AND s.expires_at > now();

  IF v_tech_id IS NULL THEN
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

-- Admin saves notes visible to the technician.
CREATE OR REPLACE FUNCTION public.app_save_notes_to_tech(p_tech_id bigint, p_notes text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_saved text;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_saved := nullif(trim(p_notes), '');

  UPDATE public.technicians
  SET notes_to_tech = v_saved
  WHERE id = p_tech_id
    AND deleted_at IS NULL
  RETURNING notes_to_tech INTO v_saved;

  RETURN coalesce(v_saved, '');
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_tech_comments(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_notes_to_tech(bigint, text) TO anon, authenticated;
