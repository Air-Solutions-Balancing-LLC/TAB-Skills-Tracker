-- Admin registry + technician soft-delete for TAB Skills Tracker
-- Run in Supabase -> SQL Editor (safe to re-run).
--
-- What this sets up:
--   * app_people: one registry of Admins / PMs / Technicians that admins manage.
--   * technicians.deleted_at + prev_region: soft-delete so a removed technician
--     keeps all assessment history, drops off every (region-scoped) dashboard,
--     and can be restored later.
--   * Admin-only RPCs to list / add / delete / restore people. Every admin RPC
--     verifies the caller via app_is_admin() (which reads the signed JWT email),
--     so the browser cannot grant itself admin access.

-- ── Soft-delete columns on technicians ───────────────────────────────────────
-- region is cleared on delete (so the technician disappears from region
-- dashboards) and stashed in prev_region so Restore can put it back.
ALTER TABLE public.technicians ADD COLUMN IF NOT EXISTS deleted_at  timestamptz;
ALTER TABLE public.technicians ADD COLUMN IF NOT EXISTS prev_region text;

-- ── Unified people registry ──────────────────────────────────────────────────
-- email is always stored lower-cased; UNIQUE(email) lets the RPCs upsert safely.
CREATE TABLE IF NOT EXISTS public.app_people (
  id         bigserial PRIMARY KEY,
  email      text NOT NULL UNIQUE,
  role       text NOT NULL CHECK (role IN ('admin','pm','technician')),
  full_name  text,
  tech_id    bigint REFERENCES public.technicians(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ── Backfill technicians into the registry ───────────────────────────────────
-- Only technicians with an email can sign in, so those are the ones we register.
INSERT INTO public.app_people (email, role, full_name, tech_id)
SELECT lower(trim(t.email)), 'technician', t.name, t.id
FROM public.technicians t
WHERE t.email IS NOT NULL AND trim(t.email) <> ''
ON CONFLICT (email) DO NOTHING;

-- ── Seed admins (runs after backfill so admin role wins for shared emails) ────
INSERT INTO public.app_people (email, role, full_name) VALUES
  ('paula.quintero@airadigmsolutions.com', 'admin', 'Paula Quintero'),
  ('james.obrien@airadigmsolutions.com',   'admin', 'James O''Brien'),
  ('brian.sharkey@airadigmsolutions.com',  'admin', 'Brian Sharkey')
ON CONFLICT (email) DO UPDATE SET role = 'admin';

-- ── Role helpers (read the verified email from the JWT) ───────────────────────
CREATE OR REPLACE FUNCTION public.app_my_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT role
  FROM public.app_people
  WHERE email = app_current_email()
  ORDER BY CASE role WHEN 'admin' THEN 1 WHEN 'pm' THEN 2 ELSE 3 END
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.app_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_people
    WHERE email = app_current_email() AND role = 'admin'
  );
$$;

-- ── Admin: list everyone (active + deleted technicians) ──────────────────────
-- Drop first: the return columns changed (added tech_id), which CREATE OR
-- REPLACE cannot do in place.
DROP FUNCTION IF EXISTS public.app_admin_list_people();

CREATE OR REPLACE FUNCTION public.app_admin_list_people()
RETURNS TABLE (id bigint, email text, full_name text, role text, region text, deleted boolean, tech_id bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
    SELECT p.id,
           p.email,
           COALESCE(p.full_name, t.name) AS full_name,
           p.role,
           t.region,
           (t.deleted_at IS NOT NULL) AS deleted,
           p.tech_id
    FROM public.app_people p
    LEFT JOIN public.technicians t ON t.id = p.tech_id
    ORDER BY
      CASE p.role WHEN 'admin' THEN 1 WHEN 'pm' THEN 2 ELSE 3 END,
      (t.deleted_at IS NOT NULL),
      lower(COALESCE(p.full_name, t.name, p.email));
END;
$$;

-- ── Admin: add a person (creates/links a technician row when needed) ─────────
CREATE OR REPLACE FUNCTION public.app_admin_add_person(
  p_email  text,
  p_role   text,
  p_name   text DEFAULT NULL,
  p_region text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email     text := lower(trim(p_email));
  v_tech_id   bigint;
  v_person_id bigint;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_email IS NULL OR v_email = '' THEN
    RAISE EXCEPTION 'Email is required';
  END IF;
  IF p_role NOT IN ('admin','pm','technician') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  IF NOT app_allowed_email(v_email) THEN
    RAISE EXCEPTION 'Email domain is not allowed';
  END IF;

  IF p_role = 'technician' THEN
    IF p_region IS NULL OR trim(p_region) = '' THEN
      RAISE EXCEPTION 'Region is required for a technician';
    END IF;

    -- Reuse an existing technician row for this email if there is one (this also
    -- doubles as a restore), otherwise create a new technician.
    SELECT id INTO v_tech_id
    FROM public.technicians
    WHERE lower(trim(email)) = v_email;

    IF v_tech_id IS NULL THEN
      INSERT INTO public.technicians (name, email, region)
      VALUES (COALESCE(NULLIF(trim(p_name), ''), v_email), v_email, p_region)
      RETURNING id INTO v_tech_id;
    ELSE
      UPDATE public.technicians
      SET region      = p_region,
          deleted_at  = NULL,
          prev_region = NULL,
          email       = v_email,
          name        = COALESCE(NULLIF(trim(p_name), ''), name)
      WHERE id = v_tech_id;
    END IF;
  END IF;

  INSERT INTO public.app_people (email, role, full_name, tech_id)
  VALUES (v_email, p_role, NULLIF(trim(p_name), ''), v_tech_id)
  ON CONFLICT (email) DO UPDATE
    SET role      = EXCLUDED.role,
        full_name = COALESCE(EXCLUDED.full_name, public.app_people.full_name),
        tech_id   = COALESCE(EXCLUDED.tech_id, public.app_people.tech_id)
  RETURNING id INTO v_person_id;

  RETURN v_person_id;
END;
$$;

-- ── Admin: delete a person ───────────────────────────────────────────────────
-- Technicians are soft-deleted (data kept, region cleared, login blocked).
-- Admins / PMs are removed from the registry outright.
CREATE OR REPLACE FUNCTION public.app_admin_delete_person(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_role        text;
  v_email       text;
  v_tech_id     bigint;
  v_me          text := app_current_email();
  v_admin_count int;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT role, email, tech_id INTO v_role, v_email, v_tech_id
  FROM public.app_people WHERE id = p_id;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Person not found';
  END IF;
  IF v_email = v_me THEN
    RAISE EXCEPTION 'You cannot delete your own account';
  END IF;
  IF v_role = 'admin' THEN
    SELECT count(*) INTO v_admin_count FROM public.app_people WHERE role = 'admin';
    IF v_admin_count <= 1 THEN
      RAISE EXCEPTION 'Cannot delete the last admin';
    END IF;
  END IF;

  IF v_role = 'technician' AND v_tech_id IS NOT NULL THEN
    UPDATE public.technicians
    SET prev_region = COALESCE(prev_region, region),
        region      = NULL,
        deleted_at  = now()
    WHERE id = v_tech_id AND deleted_at IS NULL;
  ELSE
    DELETE FROM public.app_people WHERE id = p_id;
  END IF;
END;
$$;

-- ── Admin: restore a soft-deleted technician ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_restore_tech(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT tech_id INTO v_tech_id FROM public.app_people WHERE id = p_id;
  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Not a technician';
  END IF;

  UPDATE public.technicians
  SET region      = COALESCE(prev_region, region),
      prev_region = NULL,
      deleted_at  = NULL
  WHERE id = v_tech_id;
END;
$$;

-- ── Admin: update a person (name, email, role for admin/pm, region for tech) ──
-- Drop the older 4-arg signature so re-running this file leaves only one version.
DROP FUNCTION IF EXISTS public.app_admin_update_person(bigint, text, text, text);

CREATE OR REPLACE FUNCTION public.app_admin_update_person(
  p_id     bigint,
  p_name   text DEFAULT NULL,
  p_email  text DEFAULT NULL,
  p_role   text DEFAULT NULL,
  p_region text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_role        text;
  v_tech_id     bigint;
  v_email       text;
  v_new_email   text := lower(trim(p_email));
  v_me          text := app_current_email();
  v_admin_count int;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT role, tech_id, email INTO v_role, v_tech_id, v_email
  FROM public.app_people WHERE id = p_id;
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Person not found';
  END IF;

  -- Name (applies to everyone; mirrored to technicians below for tech rows).
  UPDATE public.app_people
  SET full_name = COALESCE(NULLIF(trim(p_name), ''), full_name)
  WHERE id = p_id;

  -- Email change: must be an allowed domain and not already used by someone else.
  -- Kept in sync on the technician record so email-based sign-in still matches.
  IF v_new_email IS NOT NULL AND v_new_email <> '' AND v_new_email <> v_email THEN
    IF NOT app_allowed_email(v_new_email) THEN
      RAISE EXCEPTION 'Email domain is not allowed';
    END IF;
    IF EXISTS (SELECT 1 FROM public.app_people WHERE email = v_new_email AND id <> p_id) THEN
      RAISE EXCEPTION 'That email is already in use';
    END IF;
    UPDATE public.app_people SET email = v_new_email WHERE id = p_id;
    IF v_tech_id IS NOT NULL THEN
      UPDATE public.technicians SET email = v_new_email WHERE id = v_tech_id;
    END IF;
  END IF;

  -- Role change is only allowed between admin and pm (technicians stay technicians).
  IF p_role IS NOT NULL AND p_role IN ('admin','pm')
     AND v_role IN ('admin','pm') AND p_role <> v_role THEN
    IF v_role = 'admin' AND p_role <> 'admin' THEN
      IF v_email = v_me THEN
        RAISE EXCEPTION 'You cannot change your own admin role';
      END IF;
      SELECT count(*) INTO v_admin_count FROM public.app_people WHERE role = 'admin';
      IF v_admin_count <= 1 THEN
        RAISE EXCEPTION 'Cannot remove the last admin';
      END IF;
    END IF;
    UPDATE public.app_people SET role = p_role WHERE id = p_id;
  END IF;

  -- Region + name on the technician record (active technicians only).
  IF v_role = 'technician' AND v_tech_id IS NOT NULL THEN
    UPDATE public.technicians
    SET region = CASE WHEN p_region IS NOT NULL AND trim(p_region) <> '' THEN p_region ELSE region END,
        name   = COALESCE(NULLIF(trim(p_name), ''), name)
    WHERE id = v_tech_id AND deleted_at IS NULL;
  END IF;
END;
$$;

-- ── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.app_my_role()                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_is_admin()                            TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_people()                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_add_person(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_delete_person(bigint)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_restore_tech(bigint)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_update_person(bigint, text, text, text, text) TO authenticated;
