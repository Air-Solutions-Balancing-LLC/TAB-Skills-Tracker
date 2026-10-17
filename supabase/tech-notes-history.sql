-- Notes to Tech history (append-only entries with archive / soft-delete).
-- Requires app_can_edit_tech_notes from tech-notes-all-edit.sql.
-- Safe to re-run.

CREATE TABLE IF NOT EXISTS public.tech_note_entries (
  id bigserial PRIMARY KEY,
  tech_id bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text,
  archived_at timestamptz,
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS tech_note_entries_tech_active_idx
  ON public.tech_note_entries (tech_id, created_at DESC)
  WHERE deleted_at IS NULL;

INSERT INTO public.tech_note_entries (tech_id, body, created_at, created_by)
SELECT t.id, trim(t.notes_to_tech), now(), 'migrated'
FROM public.technicians t
WHERE t.deleted_at IS NULL
  AND nullif(trim(coalesce(t.notes_to_tech, '')), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.tech_note_entries e WHERE e.tech_id = t.id
  );

CREATE OR REPLACE FUNCTION public.app_tech_notes_sync_latest(p_tech_id bigint)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_body text;
BEGIN
  SELECT e.body INTO v_body
  FROM public.tech_note_entries e
  WHERE e.tech_id = p_tech_id
    AND e.deleted_at IS NULL
    AND e.archived_at IS NULL
  ORDER BY e.created_at DESC, e.id DESC
  LIMIT 1;

  UPDATE public.technicians
     SET notes_to_tech = v_body
   WHERE id = p_tech_id
     AND deleted_at IS NULL;

  RETURN coalesce(v_body, '');
END;
$$;

CREATE OR REPLACE FUNCTION public.app_tech_notes_list(
  p_tech_id bigint,
  p_token text DEFAULT NULL,
  p_include_archived boolean DEFAULT true
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_rows json;
  v_latest json;
BEGIN
  IF NOT public.app_can_edit_tech_notes(p_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.created_at DESC, x.id DESC), '[]'::json)
    INTO v_rows
  FROM (
    SELECT
      e.id,
      e.tech_id,
      e.body,
      e.created_at,
      e.created_by,
      e.archived_at,
      (e.archived_at IS NOT NULL) AS archived
    FROM public.tech_note_entries e
    WHERE e.tech_id = p_tech_id
      AND e.deleted_at IS NULL
      AND (p_include_archived OR e.archived_at IS NULL)
    ORDER BY e.created_at DESC, e.id DESC
  ) x;

  SELECT row_to_json(l) INTO v_latest
  FROM (
    SELECT
      e.id,
      e.tech_id,
      e.body,
      e.created_at,
      e.created_by,
      e.archived_at,
      false AS archived
    FROM public.tech_note_entries e
    WHERE e.tech_id = p_tech_id
      AND e.deleted_at IS NULL
      AND e.archived_at IS NULL
    ORDER BY e.created_at DESC, e.id DESC
    LIMIT 1
  ) l;

  RETURN json_build_object(
    'tech_id', p_tech_id,
    'latest', v_latest,
    'history', v_rows
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_tech_notes_add(
  p_tech_id bigint,
  p_body text,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_by text;
BEGIN
  IF NOT public.app_can_edit_tech_notes(p_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_body IS NULL THEN
    RAISE EXCEPTION 'Note cannot be empty';
  END IF;

  BEGIN
    SELECT nullif(trim(auth.jwt() ->> 'email'), '') INTO v_by;
  EXCEPTION WHEN OTHERS THEN
    v_by := NULL;
  END;

  INSERT INTO public.tech_note_entries (tech_id, body, created_by)
  VALUES (p_tech_id, v_body, v_by);

  PERFORM public.app_tech_notes_sync_latest(p_tech_id);
  RETURN public.app_tech_notes_list(p_tech_id, p_token, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_tech_notes_set_archived(
  p_id bigint,
  p_archived boolean,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
BEGIN
  SELECT e.tech_id INTO v_tech_id
  FROM public.tech_note_entries e
  WHERE e.id = p_id AND e.deleted_at IS NULL;

  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;
  IF NOT public.app_can_edit_tech_notes(v_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.tech_note_entries
     SET archived_at = CASE WHEN coalesce(p_archived, true) THEN coalesce(archived_at, now()) ELSE NULL END
   WHERE id = p_id;

  PERFORM public.app_tech_notes_sync_latest(v_tech_id);
  RETURN public.app_tech_notes_list(v_tech_id, p_token, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_tech_notes_delete(
  p_id bigint,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
BEGIN
  SELECT e.tech_id INTO v_tech_id
  FROM public.tech_note_entries e
  WHERE e.id = p_id AND e.deleted_at IS NULL;

  IF v_tech_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;
  IF NOT public.app_can_edit_tech_notes(v_tech_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.tech_note_entries
     SET deleted_at = now()
   WHERE id = p_id;

  PERFORM public.app_tech_notes_sync_latest(v_tech_id);
  RETURN public.app_tech_notes_list(v_tech_id, p_token, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_tech_notes_sync_latest(bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_notes_list(bigint, text, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_notes_add(bigint, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_notes_set_archived(bigint, boolean, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_tech_notes_delete(bigint, text) TO anon, authenticated;
