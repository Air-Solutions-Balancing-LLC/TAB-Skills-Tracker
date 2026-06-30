-- Admin: open an editable technician session (act as that technician)
-- Run in Supabase -> SQL Editor AFTER supabase/admin.sql and azure-login.sql.
-- Safe to re-run (CREATE OR REPLACE).

CREATE OR REPLACE FUNCTION public.app_admin_tech_edit_session(p_tech_id bigint)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
DECLARE
  v_region text;
  v_token  text;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT t.region
  INTO v_region
  FROM public.technicians t
  WHERE t.id = p_tech_id
    AND t.deleted_at IS NULL;

  IF v_region IS NULL THEN
    RETURN NULL;
  END IF;

  v_token := encode(gen_random_bytes(32), 'hex');

  INSERT INTO public.sessions (token, role, region, tech_id, expires_at)
  VALUES (v_token, 'technician', v_region, p_tech_id, now() + interval '12 hours');

  RETURN v_token;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_tech_edit_session(bigint) TO authenticated;
