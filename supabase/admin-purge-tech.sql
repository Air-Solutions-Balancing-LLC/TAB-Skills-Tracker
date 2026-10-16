-- Permanently delete an already-archived (soft-deleted) technician.
-- Run in Supabase → SQL Editor. Safe to re-run.
--
-- Soft-delete (Archive) keeps history and allows Restore.
-- This purge only works after Archive, and removes the person + technician row
-- (related assessment / ATA / checklist rows cascade with the technician).

CREATE OR REPLACE FUNCTION public.app_admin_purge_tech(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_role    text;
  v_email   text;
  v_tech_id bigint;
  v_me      text := app_current_email();
  v_deleted timestamptz;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT p.role, p.email, p.tech_id, t.deleted_at
    INTO v_role, v_email, v_tech_id, v_deleted
  FROM public.app_people p
  LEFT JOIN public.technicians t ON t.id = p.tech_id
  WHERE p.id = p_id;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Person not found';
  END IF;
  IF v_role <> 'technician' OR v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Only archived technicians can be permanently deleted';
  END IF;
  IF v_email = v_me THEN
    RAISE EXCEPTION 'You cannot delete your own account';
  END IF;
  IF v_deleted IS NULL THEN
    RAISE EXCEPTION 'Archive the technician first, then Delete';
  END IF;

  DELETE FROM public.app_people WHERE id = p_id;
  DELETE FROM public.technicians WHERE id = v_tech_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_purge_tech(bigint) TO authenticated;
