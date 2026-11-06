-- Fix Supabase Security Advisor alerts:
--   * rls_disabled_in_public
--   * sensitive_columns_exposed
--
-- TAB Skills Tracker never reads/writes tables from the browser directly.
-- The SPA only calls SECURITY DEFINER RPCs (app_*), which keep working after
-- RLS is enabled because they run as the function owner and bypass RLS.
--
-- This script:
--   1) Enables RLS on every public table (blocks Data API with no policies)
--   2) Revokes direct table privileges from anon + authenticated
--   3) Leaves EXECUTE grants on RPCs unchanged
--
-- Run in Supabase → SQL Editor (safe to re-run).
-- After running, refresh Database → Security Advisor; both Critical issues should clear.

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.relname AS tablename
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'  -- ordinary tables only
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
    -- No policies on purpose: anon/authenticated get zero rows via PostgREST.
    -- Do NOT use FORCE ROW LEVEL SECURITY — that would break SECURITY DEFINER RPCs.
  END LOOP;
END $$;

-- Take back default table grants. Without this, some advisors still warn even
-- with RLS on. SECURITY DEFINER functions are owned by a privileged role and
-- do not need these grants to read/write tables.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

-- Schema usage is still required so /rpc can resolve function names.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Ensure future tables also start locked down for API roles.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

-- Quick verification (run as a check query afterward if you want):
-- SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
-- FROM pg_class c
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public' AND c.relkind = 'r'
-- ORDER BY 1;
