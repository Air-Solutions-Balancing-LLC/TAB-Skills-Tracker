ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS ata_archived_at timestamptz;

-- ATA Teachable enrollments — create new techs and fill empty Basic (etc.)
-- start dates from course enrollment, not from a quiz. Safe to re-run.
-- Run AFTER supabase/ata-archive.sql.

CREATE OR REPLACE FUNCTION public.ata_program_is_complete(p_tech_id bigint, p_program text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (SELECT 1 FROM ata_lessons WHERE program = p_program)
     AND NOT EXISTS (
       SELECT 1 FROM ata_lessons l
        WHERE l.program = p_program
          AND NOT EXISTS (
            SELECT 1 FROM ata_completions c
             WHERE c.tech_id = p_tech_id
               AND c.lesson_code = l.lesson_code
               AND (c.passed = true OR coalesce(c.score_percent, 0) >= 80)
          )
     );
$$;

CREATE OR REPLACE FUNCTION public.app_ata_import_enrollments(p_secret text, p_rows jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret  text;
  r         jsonb;
  v_email   text;
  v_name    text;
  v_prog    text;
  v_at      date;
  v_tid     bigint;
  v_created int := 0;
  v_starts  int := 0;
  v_matched int := 0;
  v_skip    int := 0;
  v_n       int := 0;
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RETURN json_build_object('ok', false, 'error', 'invalid_rows');
  END IF;

  FOR r IN SELECT value FROM jsonb_array_elements(p_rows)
  LOOP
    v_email := lower(trim(coalesce(r->>'email', '')));
    v_name  := nullif(trim(coalesce(r->>'name', '')), '');
    v_prog  := lower(trim(coalesce(r->>'program', '')));
    v_at    := coalesce((r->>'enrolled_at')::timestamptz AT TIME ZONE 'America/New_York', now() AT TIME ZONE 'America/New_York')::date;
    v_tid   := NULL;

    IF v_email = '' OR NOT app_allowed_email(v_email) THEN
      v_skip := v_skip + 1;
      CONTINUE;
    END IF;
    IF v_prog NOT IN ('basic', 'intermediate', 'advanced') THEN
      CONTINUE;
    END IF;
    -- Only recent enrollments auto-start a clock (avoids marking veterans Behind).
    IF v_at < (now() AT TIME ZONE 'America/New_York')::date - 180 THEN
      CONTINUE;
    END IF;

    SELECT id INTO v_tid FROM technicians
     WHERE email IS NOT NULL AND lower(trim(email)) = v_email
     LIMIT 1;

    IF v_tid IS NOT NULL AND EXISTS (
      SELECT 1 FROM technicians WHERE id = v_tid AND deleted_at IS NOT NULL
    ) THEN
      v_skip := v_skip + 1;
      CONTINUE;
    END IF;

    IF v_tid IS NULL THEN
      INSERT INTO technicians (name, email, region)
      VALUES (coalesce(v_name, v_email), v_email, 'National')
      RETURNING id INTO v_tid;
      INSERT INTO app_people (email, role, full_name, region, tech_id)
      VALUES (v_email, 'technician', v_name, 'National', v_tid)
      ON CONFLICT (email) DO UPDATE
        SET tech_id   = COALESCE(app_people.tech_id, EXCLUDED.tech_id),
            full_name = COALESCE(app_people.full_name, EXCLUDED.full_name)
      WHERE app_people.role = 'technician';
      v_created := v_created + 1;
    ELSE
      IF v_name IS NOT NULL THEN
        UPDATE technicians SET name = coalesce(nullif(trim(name), ''), v_name)
         WHERE id = v_tid AND (name IS NULL OR trim(name) = '');
      END IF;
      v_matched := v_matched + 1;
    END IF;

    IF EXISTS (SELECT 1 FROM technicians WHERE id = v_tid AND ata_archived_at IS NOT NULL) THEN
      CONTINUE;
    END IF;

    IF v_prog = 'intermediate' AND NOT ata_program_is_complete(v_tid, 'basic') THEN
      CONTINUE;
    END IF;
    IF v_prog = 'advanced' AND NOT ata_program_is_complete(v_tid, 'intermediate') THEN
      CONTINUE;
    END IF;

    INSERT INTO ata_program_starts (tech_id, program, start_date, updated_at)
    VALUES (v_tid, v_prog, v_at, now())
    ON CONFLICT (tech_id, program) DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_starts := v_starts + v_n;
  END LOOP;

  RETURN json_build_object(
    'ok', true,
    'created', v_created,
    'matched', v_matched,
    'starts', v_starts,
    'skipped', v_skip
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ata_program_is_complete(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_import_enrollments(text, jsonb) TO anon, authenticated;
