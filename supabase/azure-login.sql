-- Supabase Auth login for TAB Skills Tracker
-- Run in Supabase → SQL Editor.
--
-- Security model (same as CxTrack / Airadigm Intake):
--   * Users sign in through Supabase Auth → Microsoft (Azure) provider.
--   * These functions read the VERIFIED email from the signed token via auth.jwt(),
--     so the browser can no longer claim to be someone it isn't.
--   * Project Managers: any allowed company account → pick a region.
--   * Technicians: their verified email must match a row in `technicians`.
--
-- Allowed domains live in app_allowed_email() below — edit that one function
-- if you ever need to add or remove a company domain.

-- ── Which Microsoft email domains are allowed in ─────────────────────────────
CREATE OR REPLACE FUNCTION public.app_allowed_email(p_email text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT lower(split_part(trim(p_email), '@', 2)) IN (
    'airadigmsolutions.com',
    'kitchenenergysolutions.com'
  );
$$;

-- ── The verified email of the currently signed-in user ───────────────────────
CREATE OR REPLACE FUNCTION public.app_current_email()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT lower(trim(coalesce(
    auth.jwt() ->> 'email',
    auth.jwt() -> 'user_metadata' ->> 'email'
  )));
$$;

-- ── Technicians are matched to a person by their Microsoft email ─────────────
ALTER TABLE public.technicians ADD COLUMN IF NOT EXISTS email text;
CREATE INDEX IF NOT EXISTS technicians_email_lower_idx ON public.technicians (lower(email));

-- ── Ephemeral login sessions ─────────────────────────────────────────────────
-- Sessions live in the pre-existing `public.sessions` table that the rest of the
-- app reads from (app_pm_dashboard / app_tech_home / app_submit_assessment all
-- look up the token there). The login functions below INSERT into the same table
-- so a token minted at sign-in is immediately valid for those reads.

-- ── PM login: allowed company account + chosen region → session ──────────────
-- Note: no email parameter. The email is taken from the signed-in user's token.
CREATE OR REPLACE FUNCTION public.app_pm_azure_login(p_region text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
-- `extensions` is on the path so gen_random_bytes() (pgcrypto) resolves.
SET search_path TO public, extensions
AS $$
DECLARE
  v_email text := app_current_email();
  v_token text;
BEGIN
  IF v_email IS NULL OR NOT app_allowed_email(v_email) THEN
    RETURN NULL;
  END IF;

  v_token := encode(gen_random_bytes(32), 'hex');

  INSERT INTO sessions (token, role, region, tech_id, expires_at)
  VALUES (v_token, 'pm', p_region, NULL, now() + interval '12 hours');

  RETURN v_token;
END;
$$;

-- ── Technician login: verified email must exist in `technicians` ─────────────
CREATE OR REPLACE FUNCTION public.app_tech_azure_login()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
-- `extensions` is on the path so gen_random_bytes() (pgcrypto) resolves.
SET search_path TO public, extensions
AS $$
DECLARE
  v_email text := app_current_email();
  v_tech_id bigint;
  v_token text;
BEGIN
  IF v_email IS NULL OR NOT app_allowed_email(v_email) THEN
    RETURN NULL;
  END IF;

  -- deleted_at IS NULL skips soft-deleted technicians (see supabase/admin.sql).
  SELECT id INTO v_tech_id
  FROM technicians
  WHERE email IS NOT NULL
    AND lower(trim(email)) = v_email
    AND deleted_at IS NULL;

  IF v_tech_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_token := encode(gen_random_bytes(32), 'hex');

  INSERT INTO sessions (token, role, region, tech_id, expires_at)
  VALUES (v_token, 'technician', NULL, v_tech_id, now() + interval '12 hours');

  RETURN v_token;
END;
$$;

-- Old signatures (with p_email) are no longer used — drop them so nothing calls them.
DROP FUNCTION IF EXISTS public.app_pm_azure_login(text, text);
DROP FUNCTION IF EXISTS public.app_tech_azure_login(text);

GRANT EXECUTE ON FUNCTION public.app_allowed_email(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_current_email() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_azure_login(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_azure_login() TO authenticated;
