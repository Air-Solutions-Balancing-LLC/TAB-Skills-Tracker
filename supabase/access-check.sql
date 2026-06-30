-- Access check after Microsoft sign-in
-- Run in Supabase -> SQL Editor AFTER supabase/admin.sql and azure-login.sql.
-- Safe to re-run (CREATE OR REPLACE).

CREATE OR REPLACE FUNCTION public.app_access_status()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email    text := app_current_email();
  v_role     text;
  v_can_tech boolean;
BEGIN
  IF v_email IS NULL OR NOT app_allowed_email(v_email) THEN
    RETURN json_build_object(
      'has_access', false,
      'registry_role', null,
      'can_tech_login', false
    );
  END IF;

  SELECT p.role
  INTO v_role
  FROM public.app_people p
  WHERE p.email = v_email
  ORDER BY CASE p.role WHEN 'admin' THEN 1 WHEN 'pm' THEN 2 ELSE 3 END
  LIMIT 1;

  SELECT EXISTS (
    SELECT 1
    FROM public.technicians t
    WHERE t.email IS NOT NULL
      AND lower(trim(t.email)) = v_email
      AND t.deleted_at IS NULL
  ) INTO v_can_tech;

  RETURN json_build_object(
    'has_access', (v_role IN ('admin', 'pm') OR v_can_tech),
    'registry_role', v_role,
    'can_tech_login', v_can_tech
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_access_status() TO authenticated;
