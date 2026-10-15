-- ATA admin: master curriculum CRUD + editable per-tech progress.
-- Run in Supabase → SQL Editor AFTER ata-tracking / ata-attempts / ata-manual-resets / ata-archive.
-- Safe to re-run.

-- ── Protect admin-edited scores from Teachable/Zapier overwrite ───────────────
ALTER TABLE public.ata_completions
  ADD COLUMN IF NOT EXISTS admin_locked boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.ata_completions_guard_admin_lock()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND coalesce(OLD.admin_locked, false) = true
     AND current_setting('app.ata_admin_edit', true) IS DISTINCT FROM '1' THEN
    NEW.score_percent := OLD.score_percent;
    NEW.passed := OLD.passed;
    NEW.completed_at := OLD.completed_at;
    NEW.admin_locked := true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ata_completions_guard_admin_lock ON public.ata_completions;
CREATE TRIGGER trg_ata_completions_guard_admin_lock
  BEFORE UPDATE ON public.ata_completions
  FOR EACH ROW
  EXECUTE FUNCTION public.ata_completions_guard_admin_lock();

-- Roster JSON: include admin_locked on completions
CREATE OR REPLACE FUNCTION public.app_ata_roster_json(p_region text DEFAULT NULL)
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT json_build_object(
    'techs', coalesce((
      SELECT json_agg(row_to_json(x) ORDER BY x.name)
      FROM (
        SELECT
          t.id, t.name, t.region, t.email,
          (t.ata_archived_at IS NOT NULL) AS ata_archived,
          t.ata_archived_at,
          (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
             FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
          (SELECT coalesce(json_object_agg(c.lesson_code,
             json_build_object(
               'score', c.score_percent,
               'completed_at', c.completed_at,
               'passed', c.passed,
               'admin_locked', c.admin_locked
             )), '{}'::json)
             FROM ata_completions c WHERE c.tech_id = t.id) AS completions,
          (SELECT coalesce(json_object_agg(s.lesson_code, s.info), '{}'::json) FROM (
             SELECT lesson_code, json_build_object(
               'count', count(*) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
               'best', max(score_percent) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
               'passed', bool_or(coalesce(passed,false)),
               'last_at', max(attempted_at) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
               'last_score', (array_agg(score_percent ORDER BY attempted_at DESC)
                              FILTER (WHERE source IS DISTINCT FROM 'manual_reset'))[1],
               'month_count', count(*) FILTER (WHERE attempted_at >= date_trunc('month', now())
                              AND source IS DISTINCT FROM 'manual_reset'),
               'manual_month', count(*) FILTER (WHERE source = 'manual_reset'
                              AND attempted_at >= date_trunc('month', now())),
               'manual_total', count(*) FILTER (WHERE source = 'manual_reset')
             ) AS info
             FROM ata_attempts WHERE tech_id = t.id GROUP BY lesson_code
          ) s) AS attempts
        FROM technicians t
        WHERE t.deleted_at IS NULL
          AND (p_region IS NULL OR t.region = p_region)
      ) x
    ), '[]'::json),
    'last_import', (
      SELECT row_to_json(l) FROM (
        SELECT ran_at, matched, unmatched, applied
        FROM ata_import_log ORDER BY ran_at DESC LIMIT 1
      ) l
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.app_ata_tech_data(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tech_id bigint;
  v_tech    json;
BEGIN
  SELECT s.tech_id INTO v_tech_id
  FROM sessions s
  WHERE s.token = p_token AND s.role = 'technician' AND s.expires_at > now();

  IF v_tech_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT row_to_json(x) INTO v_tech
  FROM (
    SELECT
      t.id, t.name, t.region, t.email,
      (t.ata_archived_at IS NOT NULL) AS ata_archived,
      t.ata_archived_at,
      (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
         FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
      (SELECT coalesce(json_object_agg(c.lesson_code,
         json_build_object(
           'score', c.score_percent,
           'completed_at', c.completed_at,
           'passed', c.passed,
           'admin_locked', c.admin_locked
         )), '{}'::json)
         FROM ata_completions c WHERE c.tech_id = t.id) AS completions,
      (SELECT coalesce(json_object_agg(s.lesson_code, s.info), '{}'::json) FROM (
         SELECT lesson_code, json_build_object(
           'count', count(*) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
           'best', max(score_percent) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
           'passed', bool_or(coalesce(passed,false)),
           'last_at', max(attempted_at) FILTER (WHERE source IS DISTINCT FROM 'manual_reset'),
           'last_score', (array_agg(score_percent ORDER BY attempted_at DESC)
                          FILTER (WHERE source IS DISTINCT FROM 'manual_reset'))[1],
           'month_count', count(*) FILTER (WHERE attempted_at >= date_trunc('month', now())
                          AND source IS DISTINCT FROM 'manual_reset'),
           'manual_month', count(*) FILTER (WHERE source = 'manual_reset'
                          AND attempted_at >= date_trunc('month', now())),
           'manual_total', count(*) FILTER (WHERE source = 'manual_reset')
         ) AS info
         FROM ata_attempts WHERE tech_id = t.id GROUP BY lesson_code
      ) s) AS attempts
    FROM technicians t
    WHERE t.id = v_tech_id AND t.deleted_at IS NULL
  ) x;

  RETURN v_tech;
END;
$$;

-- ── Admin: set / clear a lesson completion (locks against Teachable overwrite) ─
CREATE OR REPLACE FUNCTION public.app_ata_admin_set_completion(
  p_tech_id bigint,
  p_lesson_code text,
  p_score_percent numeric DEFAULT NULL,
  p_passed boolean DEFAULT NULL,
  p_completed_at timestamptz DEFAULT NULL,
  p_clear boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_code text := upper(trim(coalesce(p_lesson_code,'')));
  v_score numeric;
  v_passed boolean;
  v_at timestamptz;
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_tech_id IS NULL THEN RAISE EXCEPTION 'Technician required'; END IF;
  IF v_code = '' OR NOT EXISTS (SELECT 1 FROM ata_lessons WHERE lesson_code = v_code) THEN
    RAISE EXCEPTION 'Unknown lesson code';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM technicians WHERE id = p_tech_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Technician not found';
  END IF;

  PERFORM set_config('app.ata_admin_edit', '1', true);

  IF coalesce(p_clear, false) THEN
    DELETE FROM ata_completions WHERE tech_id = p_tech_id AND lesson_code = v_code;
    RETURN json_build_object('ok', true, 'cleared', true, 'lesson_code', v_code);
  END IF;

  v_score := p_score_percent;
  IF v_score IS NOT NULL AND v_score <= 1 AND v_score > 0 THEN
    v_score := v_score * 100;
  END IF;
  v_passed := coalesce(p_passed, (v_score IS NOT NULL AND v_score >= 80));
  v_at := CASE
    WHEN v_passed THEN coalesce(p_completed_at, now())
    ELSE p_completed_at
  END;

  INSERT INTO ata_completions (tech_id, lesson_code, score_percent, completed_at, passed, admin_locked, updated_at)
  VALUES (p_tech_id, v_code, v_score, v_at, v_passed, true, now())
  ON CONFLICT (tech_id, lesson_code) DO UPDATE
    SET score_percent = EXCLUDED.score_percent,
        passed = EXCLUDED.passed,
        completed_at = EXCLUDED.completed_at,
        admin_locked = true,
        updated_at = now();

  RETURN json_build_object(
    'ok', true,
    'lesson_code', v_code,
    'score', v_score,
    'passed', v_passed,
    'admin_locked', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_admin_unlock_completion(
  p_tech_id bigint,
  p_lesson_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_code text := upper(trim(coalesce(p_lesson_code,'')));
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  PERFORM set_config('app.ata_admin_edit', '1', true);
  UPDATE ata_completions
     SET admin_locked = false, updated_at = now()
   WHERE tech_id = p_tech_id AND lesson_code = v_code;
  RETURN json_build_object('ok', true, 'unlocked', FOUND);
END;
$$;

-- ── Master curriculum admin ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_admin_list_lessons()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'id', l.id,
             'program', l.program,
             'lesson_code', l.lesson_code,
             'lesson_name', l.lesson_name,
             'sort_order', l.sort_order,
             'week_index', l.week_index
           )
           ORDER BY CASE l.program
             WHEN 'basic' THEN 1 WHEN 'intermediate' THEN 2 WHEN 'advanced' THEN 3 ELSE 9 END,
             l.sort_order, l.id
         ), '[]'::jsonb)
    INTO v_result
    FROM ata_lessons l;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_admin_upsert_lesson(
  p_id bigint DEFAULT NULL,
  p_program text DEFAULT NULL,
  p_lesson_code text DEFAULT NULL,
  p_lesson_name text DEFAULT NULL,
  p_sort_order int DEFAULT NULL,
  p_week_index int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id bigint;
  v_old_code text;
  v_code text;
  v_name text;
  v_program text;
  v_sort int;
  v_week int;
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_code := upper(trim(coalesce(p_lesson_code,'')));
  v_name := trim(coalesce(p_lesson_name,''));
  v_program := lower(trim(coalesce(p_program,'')));

  IF p_id IS NOT NULL THEN
    SELECT id, lesson_code, program, lesson_name, sort_order, week_index
      INTO v_id, v_old_code, v_program, v_name, v_sort, v_week
      FROM ata_lessons WHERE id = p_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'Lesson not found'; END IF;

    IF p_program IS NOT NULL AND trim(p_program) <> '' THEN
      v_program := lower(trim(p_program));
    END IF;
    IF p_lesson_code IS NOT NULL AND trim(p_lesson_code) <> '' THEN
      v_code := upper(trim(p_lesson_code));
    ELSE
      v_code := v_old_code;
    END IF;
    IF p_lesson_name IS NOT NULL AND trim(p_lesson_name) <> '' THEN
      v_name := trim(p_lesson_name);
    END IF;
    IF p_sort_order IS NOT NULL THEN v_sort := p_sort_order; END IF;
    IF p_week_index IS NOT NULL THEN v_week := p_week_index; END IF;
  ELSE
    IF v_program NOT IN ('basic','intermediate','advanced') THEN
      RAISE EXCEPTION 'Program must be basic, intermediate, or advanced';
    END IF;
    IF v_code = '' THEN RAISE EXCEPTION 'Lesson code is required'; END IF;
    IF v_name = '' THEN RAISE EXCEPTION 'Lesson name is required'; END IF;
    SELECT COALESCE(max(sort_order), 0) + 1 INTO v_sort FROM ata_lessons WHERE program = v_program;
    v_week := coalesce(p_week_index, v_sort);
    v_sort := coalesce(p_sort_order, v_sort);
  END IF;

  IF v_program NOT IN ('basic','intermediate','advanced') THEN
    RAISE EXCEPTION 'Program must be basic, intermediate, or advanced';
  END IF;
  IF v_code = '' OR v_name = '' THEN
    RAISE EXCEPTION 'Lesson code and name are required';
  END IF;
  IF v_code !~ '^TAB-[BIA]-[0-9]+$' THEN
    RAISE EXCEPTION 'Lesson code must look like TAB-B-101, TAB-I-102, or TAB-A-201';
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO ata_lessons (program, lesson_code, lesson_name, sort_order, week_index)
    VALUES (v_program, v_code, v_name, v_sort, v_week)
    RETURNING id INTO v_id;
  ELSE
    -- Renaming a code migrates everyone's progress so requirements stay linked.
    IF v_code IS DISTINCT FROM v_old_code THEN
      IF EXISTS (SELECT 1 FROM ata_lessons WHERE lesson_code = v_code AND id <> p_id) THEN
        RAISE EXCEPTION 'Lesson code already exists';
      END IF;
      -- Drop old rows that would collide with an existing new-code row for the same tech.
      DELETE FROM ata_completions a
       USING ata_completions b
       WHERE a.lesson_code = v_old_code
         AND b.lesson_code = v_code
         AND a.tech_id = b.tech_id;
      UPDATE ata_completions SET lesson_code = v_code WHERE lesson_code = v_old_code;
      UPDATE ata_attempts SET lesson_code = v_code WHERE lesson_code = v_old_code;
    END IF;
    UPDATE ata_lessons
       SET program = v_program,
           lesson_code = v_code,
           lesson_name = v_name,
           sort_order = v_sort,
           week_index = v_week
     WHERE id = p_id
     RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object(
    'id', v_id,
    'program', v_program,
    'lesson_code', v_code,
    'lesson_name', v_name,
    'sort_order', v_sort,
    'week_index', v_week
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_admin_delete_lesson(p_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_code text;
  v_comp int;
  v_att int;
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT lesson_code INTO v_code FROM ata_lessons WHERE id = p_id;
  IF v_code IS NULL THEN RAISE EXCEPTION 'Lesson not found'; END IF;

  SELECT count(*) INTO v_comp FROM ata_completions WHERE lesson_code = v_code;
  SELECT count(*) INTO v_att FROM ata_attempts WHERE lesson_code = v_code;

  DELETE FROM ata_lessons WHERE id = p_id;
  -- Leave historical completions/attempts keyed by the old code so audits remain;
  -- they simply no longer appear on the active curriculum schedule.

  RETURN json_build_object(
    'ok', true,
    'lesson_code', v_code,
    'orphan_completions', v_comp,
    'orphan_attempts', v_att
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_ata_admin_reorder_lessons(p_program text, p_ids bigint[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  i int;
  v_program text := lower(trim(coalesce(p_program,'')));
BEGIN
  IF NOT app_is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF v_program NOT IN ('basic','intermediate','advanced') THEN
    RAISE EXCEPTION 'Invalid program';
  END IF;
  FOR i IN 1..COALESCE(array_length(p_ids, 1), 0) LOOP
    UPDATE ata_lessons
       SET sort_order = i,
           week_index = i
     WHERE id = p_ids[i] AND program = v_program;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ata_admin_set_completion(bigint, text, numeric, boolean, timestamptz, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_admin_unlock_completion(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_admin_list_lessons() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_admin_upsert_lesson(bigint, text, text, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_admin_delete_lesson(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_admin_reorder_lessons(text, bigint[]) TO authenticated;
