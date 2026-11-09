-- Notes next to ATA resets, plus the Brenda check-in on the report.
-- Run once in Supabase → SQL Editor. Safe to re-run.
--
-- A row with lesson_code NULL is the person-level check-in
-- ("Checked in with Brenda - good to continue ATA").
-- A row with a lesson code is the note shown next to that quiz.

CREATE TABLE IF NOT EXISTS public.ata_reset_notes (
  id          bigserial PRIMARY KEY,
  tech_id     bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  lesson_code text,
  note        text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ata_reset_notes_lesson_uidx
  ON public.ata_reset_notes (tech_id, lesson_code)
  WHERE lesson_code IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ata_reset_notes_checkin_uidx
  ON public.ata_reset_notes (tech_id)
  WHERE lesson_code IS NULL;

CREATE OR REPLACE FUNCTION public.app_ata_reset_notes(p_tech_id bigint)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN json_build_object(
    'checkin', (
      SELECT json_build_object('note', n.note, 'updated_at', n.updated_at)
      FROM ata_reset_notes n
      WHERE n.tech_id = p_tech_id AND n.lesson_code IS NULL
    ),
    'lessons', coalesce((
      SELECT json_agg(json_build_object(
        'lesson_code', n.lesson_code,
        'note', n.note,
        'updated_at', n.updated_at
      ) ORDER BY n.lesson_code)
      FROM ata_reset_notes n
      WHERE n.tech_id = p_tech_id AND n.lesson_code IS NOT NULL
    ), '[]'::json)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_reset_notes_all()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN coalesce((
    SELECT json_agg(json_build_object(
      'tech_id', n.tech_id,
      'lesson_code', n.lesson_code,
      'note', n.note,
      'updated_at', n.updated_at
    ) ORDER BY n.tech_id, n.lesson_code NULLS FIRST)
    FROM ata_reset_notes n
  ), '[]'::json);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_save_reset_note(
  p_tech_id bigint,
  p_lesson_code text,
  p_note text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_code text := nullif(upper(trim(coalesce(p_lesson_code, ''))), '');
  v_note text := nullif(trim(coalesce(p_note, '')), '');
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM technicians WHERE id = p_tech_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Unknown technician';
  END IF;
  IF v_code IS NOT NULL AND v_code !~ '^TAB-[BIA]-[0-9]+$' THEN
    RAISE EXCEPTION 'Invalid lesson code';
  END IF;

  IF v_note IS NULL THEN
    DELETE FROM ata_reset_notes
     WHERE tech_id = p_tech_id
       AND lesson_code IS NOT DISTINCT FROM v_code;
  ELSE
    UPDATE ata_reset_notes
       SET note = v_note, updated_at = now()
     WHERE tech_id = p_tech_id
       AND lesson_code IS NOT DISTINCT FROM v_code;
    IF NOT FOUND THEN
      INSERT INTO ata_reset_notes (tech_id, lesson_code, note)
      VALUES (p_tech_id, v_code, v_note);
    END IF;
  END IF;

  RETURN public.app_ata_reset_notes(p_tech_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_reset_notes(bigint)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_reset_notes_all()                TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_save_reset_note(bigint, text, text) TO authenticated;
