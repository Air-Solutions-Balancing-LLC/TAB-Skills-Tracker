-- Remove TTB Attendance from this Supabase project.
-- Paste in SQL Editor → Run. Does not touch ATA, archive, or user tables.

DROP FUNCTION IF EXISTS public.app_ttb_settings(text);
DROP FUNCTION IF EXISTS public.app_ttb_import_attendance(text, jsonb, jsonb);
DROP FUNCTION IF EXISTS public.app_admin_ttb_import_sheet(jsonb);
DROP FUNCTION IF EXISTS public.app_admin_ttb_set_session(date, boolean, text);
DROP FUNCTION IF EXISTS public.app_admin_ttb_set_cell(bigint, bigint, text, text, boolean);
DROP FUNCTION IF EXISTS public.app_admin_ttb_delete_topic(bigint);
DROP FUNCTION IF EXISTS public.app_admin_ttb_upsert_topic(bigint, text, text, text);
DROP FUNCTION IF EXISTS public.app_admin_ttb_save_settings(text, text, time, int, int);
DROP FUNCTION IF EXISTS public.app_admin_ttb_data();
DROP FUNCTION IF EXISTS public.ttb_status_from_join(timestamptz, date);
DROP FUNCTION IF EXISTS public.ttb_ensure_roster(text, text, boolean);
DROP FUNCTION IF EXISTS public.ttb_match_roster(text, text);
DROP FUNCTION IF EXISTS public.ttb_norm_name(text);

DROP TABLE IF EXISTS public.ttb_sync_log CASCADE;
DROP TABLE IF EXISTS public.ttb_topics CASCADE;
DROP TABLE IF EXISTS public.ttb_attendance CASCADE;
DROP TABLE IF EXISTS public.ttb_sessions CASCADE;
DROP TABLE IF EXISTS public.ttb_roster CASCADE;
DROP TABLE IF EXISTS public.ttb_settings CASCADE;
