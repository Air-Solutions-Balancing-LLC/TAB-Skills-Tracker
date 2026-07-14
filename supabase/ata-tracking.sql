-- ATA Tracking for TAB Skills Tracker
-- Run in Supabase → SQL Editor (after admin.sql / azure-login.sql / assessments-rpcs.sql).
--
-- What this adds:
--   * ata_lessons          — the fixed curriculum (Basic / Intermediate / Advanced),
--                            seeded from Brian Randolph's "Digital ATA Scores" template.
--   * ata_program_starts   — per-technician start date for each program. Intermediate
--                            and Advanced stay blank until the prior program is done.
--   * ata_completions      — quiz completions imported from the Google Sheet, keyed by
--                            (technician, lesson_code). Newest completion wins.
--   * ata_import_log       — one row per "Update from Sheet" run (counts + timestamp).
--
-- Security model matches the rest of the app:
--   * Admin-only writes verified via app_is_admin() (reads the signed JWT email).
--   * PM / Technician reads go through the ephemeral `sessions` token, exactly like
--     app_pm_dashboard / app_tech_home.
--   * Deadlines (one lesson per week, due the following Friday) are computed in the
--     browser from start_date + week_index, so the schedule stays flexible.

-- ── Tables ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ata_lessons (
  id           bigserial PRIMARY KEY,
  program      text NOT NULL CHECK (program IN ('basic','intermediate','advanced')),
  lesson_code  text NOT NULL UNIQUE,
  lesson_name  text NOT NULL,
  sort_order   int  NOT NULL,
  week_index   int  NOT NULL
);
CREATE INDEX IF NOT EXISTS ata_lessons_program_idx ON public.ata_lessons (program, sort_order);

CREATE TABLE IF NOT EXISTS public.ata_program_starts (
  tech_id    bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  program    text   NOT NULL CHECK (program IN ('basic','intermediate','advanced')),
  start_date date,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tech_id, program)
);

CREATE TABLE IF NOT EXISTS public.ata_completions (
  id            bigserial PRIMARY KEY,
  tech_id       bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  lesson_code   text NOT NULL,
  score_percent numeric,
  completed_at  timestamptz,
  source_email  text,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tech_id, lesson_code)
);
CREATE INDEX IF NOT EXISTS ata_completions_tech_idx ON public.ata_completions (tech_id);

CREATE TABLE IF NOT EXISTS public.ata_import_log (
  id        bigserial PRIMARY KEY,
  ran_at    timestamptz NOT NULL DEFAULT now(),
  matched   int NOT NULL DEFAULT 0,
  unmatched int NOT NULL DEFAULT 0,
  applied   int NOT NULL DEFAULT 0
);

-- ── Seed / refresh the curriculum ────────────────────────────────────────────
-- Idempotent: re-running updates names/order without touching completions.
INSERT INTO public.ata_lessons (program, lesson_code, lesson_name, sort_order, week_index) VALUES
  ('basic','TAB-B-101','Introduction to TAB',1,1),
  ('basic','TAB-B-102','Job Site Safety',2,2),
  ('basic','TAB-B-104','Job Site Etiquette',3,3),
  ('basic','TAB-B-105','Dampers',4,4),
  ('basic','TAB-B-110','Grille Balancing',5,5),
  ('basic','TAB-B-107','Mechanical Terms & Symbols',6,6),
  ('basic','TAB-B-103','TAB Math',7,7),
  ('basic','TAB-B-201','Unit Data',8,8),
  ('basic','TAB-B-202','RPMs',9,9),
  ('basic','TAB-B-203','Volts, Amps, and VFDs',10,10),
  ('basic','TAB-B-204','Static Pressures',11,11),
  ('basic','TAB-B-205','Outside Airflows',12,12),
  ('basic','TAB-B-301','Ak''s',13,13),
  ('basic','TAB-B-306','Kitchen Hoods',14,14),
  ('basic','TAB-B-307','Motor Sheave Calculations',15,15),
  ('basic','TAB-B-309','Troubleshooting Units',16,16),
  ('basic','TAB-B-106','History of TAB',17,17),
  ('basic','TAB-B-108','Mechanical Schedules',18,18),
  ('basic','TAB-B-109','Mechanical Submittals',19,19),
  ('basic','TAB-B-111','TAB Instruments',20,20),
  ('basic','TAB-B-112','Course Level Final Exam',21,21),
  ('basic','TAB-B-206','Duct Traverses',22,22),
  ('basic','TAB-B-207','Starters',23,23),
  ('basic','TAB-B-208','Writing Remarks',24,24),
  ('basic','TAB-B-209','USA Balancer',25,25),
  ('basic','TAB-B-210','Course Level Final Exam',26,26),
  ('basic','TAB-B-302','Fan Testing',27,27),
  ('basic','TAB-B-303','Economizers',28,28),
  ('basic','TAB-B-304','Energy Recovery Units',29,29),
  ('basic','TAB-B-305','Building Static Pressure',30,30),
  ('basic','TAB-B-308','Coil Face Velocity',31,31),
  ('basic','TAB-B-310','Course Level Final Exam',32,32),
  ('basic','TAB-B-401','TAB Basic Final Written Exam',33,33),
  ('basic','TAB-B-402','TAB Basic Final Practical Exams',34,34),

  ('intermediate','TAB-I-101','VAV Basics',1,1),
  ('intermediate','TAB-I-102','Calibrating a VAV',2,2),
  ('intermediate','TAB-I-103','Parallel Fan Powered Boxes',3,3),
  ('intermediate','TAB-I-104','Series Fan Powered Boxes',4,4),
  ('intermediate','TAB-I-105','Independent vs Dependent Systems',5,5),
  ('intermediate','TAB-I-106','Establishing Final SP Setpoint',6,6),
  ('intermediate','TAB-I-107','Total Unit CFM - VAV Systems',7,7),
  ('intermediate','TAB-I-108','Thermal Diffuser VAVs',8,8),
  ('intermediate','TAB-I-109','Course Level Final Exam',9,9),
  ('intermediate','TAB-I-201','HVAC Controls - Part 1',10,10),
  ('intermediate','TAB-I-202','Electronic Controls',11,11),
  ('intermediate','TAB-I-203','Pneumatic Controls',12,12),
  ('intermediate','TAB-I-204','Calibrating Airflow Monitors',13,13),
  ('intermediate','TAB-I-205','HVAC Controls - Part 2',14,14),
  ('intermediate','TAB-I-206','Commissioning',15,15),
  ('intermediate','TAB-I-207','Course Level Final Exam',16,16),
  ('intermediate','TAB-I-301','Fans and System Effect',17,17),
  ('intermediate','TAB-I-302','Fan Laws',18,18),
  ('intermediate','TAB-I-303','Troubleshooting Units',19,19),
  ('intermediate','TAB-I-304','Occupant Comfort Issues',20,20),
  ('intermediate','TAB-I-305','Setting O/A Temperature Method',21,21),
  ('intermediate','TAB-I-306','Setting O/A Static Pressure Method',22,22),
  ('intermediate','TAB-I-307','Course Level Final Exam',23,23),
  ('intermediate','TAB-I-401','Air Changes per Hour',24,24),
  ('intermediate','TAB-I-402','Fume Hoods',25,25),
  ('intermediate','TAB-I-403','Stairwell Pressures',26,26),
  ('intermediate','TAB-I-404','Building Ventilation Testing',27,27),
  ('intermediate','TAB-I-406','Course Level Final Exam',28,28),

  ('advanced','TAB-A-101','Hydronic vs Air',1,1),
  ('advanced','TAB-A-102','Hydronic Components',2,2),
  ('advanced','TAB-A-103','Chillers',3,3),
  ('advanced','TAB-A-104','Cooling Towers',4,4),
  ('advanced','TAB-A-105','Boilers',5,5),
  ('advanced','TAB-A-106','Condenser Water',6,6),
  ('advanced','TAB-A-107','Heat Pumps',7,7),
  ('advanced','TAB-A-108','Piping Systems',8,8),
  ('advanced','TAB-A-109','Primary / Secondary Piping',9,9),
  ('advanced','TAB-A-110','Course Level Final Exam',10,10),
  ('advanced','TAB-A-201','Balance Valves',11,11),
  ('advanced','TAB-A-202','Coil Balancing',12,12),
  ('advanced','TAB-A-203','Pump Balancing',13,13),
  ('advanced','TAB-A-204','CV and Equipment Pressure Drop',14,14),
  ('advanced','TAB-A-205','Heat Exchangers',15,15),
  ('advanced','TAB-A-206','Ultrasonic Flow Meters',16,16),
  ('advanced','TAB-A-207','Course Level Final Exam',17,17),
  ('advanced','TAB-A-301','Hydronic Precautions',18,18),
  ('advanced','TAB-A-302','Troubleshooting Hydronics',19,19),
  ('advanced','TAB-A-303','Solving Humidity Issues',20,20),
  ('advanced','TAB-A-304','Coil Water Carry Over',21,21),
  ('advanced','TAB-A-306','Course Level Final Exam',22,22),
  ('advanced','TAB-A-401','Duct Air Leakage Testing',23,23),
  ('advanced','TAB-A-402','Sound Testing',24,24),
  ('advanced','TAB-A-403','Vibration Testing',25,25),
  ('advanced','TAB-A-404','Chilled Beams',26,26),
  ('advanced','TAB-A-405','Off-Season Testing',27,27),
  ('advanced','TAB-A-406','Course Level Final Exam',28,28),
  ('advanced','TAB-A-501','Customer Service',29,29),
  ('advanced','TAB-A-502','Project Management',30,30),
  ('advanced','TAB-A-503','TAB Planning & Agenda',31,31),
  ('advanced','TAB-A-504','Estimating',32,32),
  ('advanced','TAB-A-505','Specifications',33,33),
  ('advanced','TAB-A-506','Submittals',34,34),
  ('advanced','TAB-A-507','Course Level Final Exam',35,35)
ON CONFLICT (lesson_code) DO UPDATE
  SET program = EXCLUDED.program,
      lesson_name = EXCLUDED.lesson_name,
      sort_order = EXCLUDED.sort_order,
      week_index = EXCLUDED.week_index;

-- ── Read: curriculum (all roles) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_curriculum()
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT coalesce(json_agg(row_to_json(l) ORDER BY
    CASE l.program WHEN 'basic' THEN 1 WHEN 'intermediate' THEN 2 ELSE 3 END,
    l.sort_order), '[]'::json)
  FROM (
    SELECT program, lesson_code, lesson_name, sort_order, week_index
    FROM ata_lessons
  ) l;
$$;

-- ── Shared: build the per-technician roster payload ───────────────────────────
-- Returns techs (with starts + completions maps) for an optional region filter.
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
          t.id,
          t.name,
          t.region,
          t.email,
          (
            SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
            FROM ata_program_starts ps
            WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL
          ) AS starts,
          (
            SELECT coalesce(json_object_agg(c.lesson_code,
              json_build_object('score', c.score_percent, 'completed_at', c.completed_at)), '{}'::json)
            FROM ata_completions c
            WHERE c.tech_id = t.id
          ) AS completions
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

-- ── Read: admin roster (all technicians) ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_admin_data()
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
  RETURN app_ata_roster_json(NULL);
END;
$$;

-- ── Read: PM roster (region-scoped, via session token) ───────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_pm_data(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
BEGIN
  SELECT s.region INTO v_region
  FROM sessions s
  WHERE s.token = p_token AND s.expires_at > now();

  IF v_region IS NULL THEN
    RETURN json_build_object('techs', '[]'::json, 'last_import', NULL);
  END IF;

  RETURN app_ata_roster_json(v_region);
END;
$$;

-- ── Read: single technician (via session token) ──────────────────────────────
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
      (
        SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
        FROM ata_program_starts ps
        WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL
      ) AS starts,
      (
        SELECT coalesce(json_object_agg(c.lesson_code,
          json_build_object('score', c.score_percent, 'completed_at', c.completed_at)), '{}'::json)
        FROM ata_completions c
        WHERE c.tech_id = t.id
      ) AS completions
    FROM technicians t
    WHERE t.id = v_tech_id AND t.deleted_at IS NULL
  ) x;

  RETURN v_tech;
END;
$$;

-- ── Write: set / clear a program start date (admin) ──────────────────────────
CREATE OR REPLACE FUNCTION public.app_ata_set_start(p_tech_id bigint, p_program text, p_start_date date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_program NOT IN ('basic','intermediate','advanced') THEN
    RAISE EXCEPTION 'Invalid program';
  END IF;

  IF p_start_date IS NULL THEN
    DELETE FROM ata_program_starts WHERE tech_id = p_tech_id AND program = p_program;
    RETURN;
  END IF;

  INSERT INTO ata_program_starts (tech_id, program, start_date, updated_at)
  VALUES (p_tech_id, p_program, p_start_date, now())
  ON CONFLICT (tech_id, program) DO UPDATE
    SET start_date = EXCLUDED.start_date, updated_at = now();
END;
$$;

-- ── Write: import completions from the Google Sheet (admin) ───────────────────
-- The published sheet has one tab per technician ("Quiz History - <Name>") with
-- Course / Quiz / Score-Status columns — no email and no completion date. So a row
-- is matched to a technician by NAME (email is used first when present as a
-- fallback for future feeds). p_rows is a JSON array of
--   {name, email, lesson_code, score, completed_at}
-- where `score` is an optional percent and `completed_at` is optional. Rows whose
-- name/email match no active technician are counted "unmatched" and skipped.
CREATE OR REPLACE FUNCTION public.app_ata_import(p_rows jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  rec          record;
  v_email      text;
  v_name       text;
  v_code       text;
  v_tid        bigint;
  v_matched    int := 0;
  v_unmatched  int := 0;
  v_applied    int := 0;
  v_rowcount   int;
  v_key        text;
  v_unmatched_names text[] := ARRAY[]::text[];
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  FOR rec IN
    SELECT *
    FROM jsonb_to_recordset(coalesce(p_rows, '[]'::jsonb))
      AS x(name text, email text, lesson_code text, score numeric, completed_at timestamptz)
  LOOP
    v_email := lower(trim(coalesce(rec.email, '')));
    v_name  := lower(trim(coalesce(rec.name, '')));
    v_code  := upper(trim(coalesce(rec.lesson_code, '')));

    -- Only accept recognizable TAB lesson codes.
    IF v_code !~ '^TAB-[BIA]-[0-9]+' THEN
      CONTINUE;
    END IF;
    -- Normalize to just the code token (strip any trailing lesson title).
    v_code := (regexp_match(v_code, '^(TAB-[BIA]-[0-9]+)'))[1];

    IF v_email = '' AND v_name = '' THEN
      CONTINUE;
    END IF;

    v_tid := NULL;

    IF v_email <> '' THEN
      SELECT id INTO v_tid
      FROM technicians
      WHERE email IS NOT NULL AND lower(trim(email)) = v_email AND deleted_at IS NULL
      LIMIT 1;
    END IF;

    IF v_tid IS NULL AND v_name <> '' THEN
      SELECT id INTO v_tid
      FROM technicians
      WHERE lower(trim(name)) = v_name AND deleted_at IS NULL
      LIMIT 1;
    END IF;

    IF v_tid IS NULL THEN
      v_unmatched := v_unmatched + 1;
      v_key := coalesce(nullif(v_name, ''), v_email);
      IF NOT (v_key = ANY(v_unmatched_names)) AND coalesce(array_length(v_unmatched_names,1),0) < 50 THEN
        v_unmatched_names := array_append(v_unmatched_names, v_key);
      END IF;
      CONTINUE;
    END IF;

    v_matched := v_matched + 1;

    INSERT INTO ata_completions (tech_id, lesson_code, score_percent, completed_at, source_email, updated_at)
    VALUES (v_tid, v_code, rec.score, rec.completed_at, nullif(v_email,''), now())
    ON CONFLICT (tech_id, lesson_code) DO UPDATE
      SET score_percent = EXCLUDED.score_percent,
          completed_at  = EXCLUDED.completed_at,
          source_email  = EXCLUDED.source_email,
          updated_at    = now()
      WHERE EXCLUDED.completed_at IS NULL
         OR ata_completions.completed_at IS NULL
         OR EXCLUDED.completed_at >= ata_completions.completed_at;

    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    v_applied := v_applied + v_rowcount;
  END LOOP;

  INSERT INTO ata_import_log (matched, unmatched, applied)
  VALUES (v_matched, v_unmatched, v_applied);

  RETURN json_build_object(
    'matched', v_matched,
    'unmatched', v_unmatched,
    'applied', v_applied,
    'unmatched_names', to_json(v_unmatched_names)
  );
END;
$$;

-- ── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.app_ata_curriculum()                              TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_roster_json(text)                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_admin_data()                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_pm_data(text)                             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_tech_data(text)                           TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_set_start(bigint, text, date)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_import(jsonb)                             TO authenticated;
