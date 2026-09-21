-- TTB (Training Touch Base) — admin-only attendance + topics.
-- Run in Supabase → SQL Editor AFTER supabase/admin.sql and supabase/ata-attempts.sql.
-- Safe to re-run.

CREATE TABLE IF NOT EXISTS public.ttb_settings (
  id                   int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  meeting_join_url     text,
  organizer_email      text,
  timezone             text NOT NULL DEFAULT 'America/New_York',
  start_local          time NOT NULL DEFAULT '14:00',
  ontime_grace_min     int  NOT NULL DEFAULT 5,
  late_cutoff_min      int  NOT NULL DEFAULT 10,
  updated_at           timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.ttb_settings (id, meeting_join_url, organizer_email)
VALUES (
  1,
  'https://teams.microsoft.com/meet/2844141263142?p=jHgN3ZFQy0PnVLd4KW',
  'brenda.zwickau@airadigmsolutions.com'
)
ON CONFLICT (id) DO UPDATE
  SET meeting_join_url = COALESCE(NULLIF(trim(ttb_settings.meeting_join_url), ''), EXCLUDED.meeting_join_url),
      organizer_email  = COALESCE(NULLIF(trim(ttb_settings.organizer_email), ''), EXCLUDED.organizer_email);

CREATE TABLE IF NOT EXISTS public.ttb_roster (
  id           bigserial PRIMARY KEY,
  display_name text NOT NULL,
  email        text,
  tech_id      bigint REFERENCES public.technicians(id) ON DELETE SET NULL,
  person_id    bigint REFERENCES public.app_people(id) ON DELETE SET NULL,
  expected     boolean NOT NULL DEFAULT true,
  optional     boolean NOT NULL DEFAULT false,
  active       boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ttb_roster_name_idx
  ON public.ttb_roster (lower(trim(display_name)));
CREATE UNIQUE INDEX IF NOT EXISTS ttb_roster_email_idx
  ON public.ttb_roster (lower(trim(email)))
  WHERE email IS NOT NULL AND trim(email) <> '';

CREATE TABLE IF NOT EXISTS public.ttb_sessions (
  id               bigserial PRIMARY KEY,
  meeting_date     date NOT NULL UNIQUE,
  cancelled        boolean NOT NULL DEFAULT false,
  topic            text,
  teams_meeting_id text,
  teams_report_id  text,
  synced_at        timestamptz
);

CREATE TABLE IF NOT EXISTS public.ttb_attendance (
  id               bigserial PRIMARY KEY,
  session_id       bigint NOT NULL REFERENCES public.ttb_sessions(id) ON DELETE CASCADE,
  roster_id        bigint REFERENCES public.ttb_roster(id) ON DELETE SET NULL,
  email            text,
  display_name     text,
  first_join       timestamptz,
  last_leave       timestamptz,
  duration_seconds int,
  status           text NOT NULL CHECK (status IN ('on_time','late','absent','excused','unmatched')),
  informed         boolean NOT NULL DEFAULT false,
  notes            text,
  source           text NOT NULL DEFAULT 'manual',
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ttb_attendance_session_roster_idx
  ON public.ttb_attendance (session_id, roster_id)
  WHERE roster_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ttb_attendance_session_email_idx
  ON public.ttb_attendance (session_id, lower(trim(email)))
  WHERE email IS NOT NULL AND trim(email) <> '';
-- Inferable unique for ON CONFLICT (null roster_id allowed more than once).
ALTER TABLE public.ttb_attendance
  DROP CONSTRAINT IF EXISTS ttb_attendance_session_roster_key;
ALTER TABLE public.ttb_attendance
  ADD CONSTRAINT ttb_attendance_session_roster_key UNIQUE (session_id, roster_id);

CREATE TABLE IF NOT EXISTS public.ttb_topics (
  id          bigserial PRIMARY KEY,
  kind        text NOT NULL CHECK (kind IN ('content','decision')),
  occurred_on text,
  body        text NOT NULL,
  sort_order  int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ttb_sync_log (
  id         bigserial PRIMARY KEY,
  ran_at     timestamptz NOT NULL DEFAULT now(),
  meeting_date date,
  matched    int NOT NULL DEFAULT 0,
  unmatched  int NOT NULL DEFAULT 0,
  absent     int NOT NULL DEFAULT 0,
  detail     jsonb
);

ALTER TABLE public.ttb_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ttb_roster ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ttb_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ttb_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ttb_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ttb_sync_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.ttb_settings FROM anon, authenticated;
REVOKE ALL ON public.ttb_roster FROM anon, authenticated;
REVOKE ALL ON public.ttb_sessions FROM anon, authenticated;
REVOKE ALL ON public.ttb_attendance FROM anon, authenticated;
REVOKE ALL ON public.ttb_topics FROM anon, authenticated;
REVOKE ALL ON public.ttb_sync_log FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.ttb_norm_name(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(lower(trim(coalesce(p, ''))), '\s+', ' ', 'g');
$$;

CREATE OR REPLACE FUNCTION public.ttb_match_roster(p_email text, p_name text)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id bigint;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_name text := ttb_norm_name(p_name);
BEGIN
  IF v_email <> '' THEN
    SELECT id INTO v_id FROM ttb_roster
     WHERE email IS NOT NULL AND lower(trim(email)) = v_email
     LIMIT 1;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;

    SELECT r.id INTO v_id
      FROM ttb_roster r
      JOIN technicians t ON t.id = r.tech_id
     WHERE t.email IS NOT NULL AND lower(trim(t.email)) = v_email
     LIMIT 1;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;

    SELECT r.id INTO v_id
      FROM ttb_roster r
      JOIN app_people p ON p.id = r.person_id
     WHERE p.email IS NOT NULL AND lower(trim(p.email)) = v_email
     LIMIT 1;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  END IF;

  IF v_name <> '' THEN
    SELECT id INTO v_id FROM ttb_roster
     WHERE ttb_norm_name(display_name) = v_name
     LIMIT 1;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;

    SELECT r.id INTO v_id
      FROM ttb_roster r
      JOIN technicians t ON t.id = r.tech_id
     WHERE ttb_norm_name(t.name) = v_name
     LIMIT 1;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;

    SELECT r.id INTO v_id
      FROM ttb_roster r
      JOIN app_people p ON p.id = r.person_id
     WHERE ttb_norm_name(p.full_name) = v_name
     LIMIT 1;
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ttb_ensure_roster(p_name text, p_email text, p_optional boolean DEFAULT false)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id bigint;
  v_email text := nullif(lower(trim(coalesce(p_email, ''))), '');
  v_name text := nullif(trim(coalesce(p_name, '')), '');
  v_tid bigint;
  v_pid bigint;
BEGIN
  v_id := ttb_match_roster(v_email, v_name);
  IF v_id IS NOT NULL THEN
    UPDATE ttb_roster
       SET email = COALESCE(email, v_email),
           display_name = CASE WHEN trim(coalesce(display_name,'')) = '' THEN coalesce(v_name, display_name) ELSE display_name END,
           optional = CASE WHEN p_optional THEN true ELSE optional END,
           active = true
     WHERE id = v_id;
    RETURN v_id;
  END IF;

  IF v_email IS NOT NULL THEN
    SELECT id INTO v_tid FROM technicians
     WHERE email IS NOT NULL AND lower(trim(email)) = v_email AND deleted_at IS NULL
     LIMIT 1;
    SELECT id INTO v_pid FROM app_people
     WHERE email IS NOT NULL AND lower(trim(email)) = v_email
     LIMIT 1;
  END IF;
  IF v_tid IS NULL AND v_name IS NOT NULL THEN
    SELECT id INTO v_tid FROM technicians
     WHERE ttb_norm_name(name) = ttb_norm_name(v_name) AND deleted_at IS NULL
     LIMIT 1;
  END IF;
  IF v_pid IS NULL AND v_name IS NOT NULL THEN
    SELECT id INTO v_pid FROM app_people
     WHERE ttb_norm_name(full_name) = ttb_norm_name(v_name)
     LIMIT 1;
  END IF;
  IF v_email IS NULL AND v_tid IS NOT NULL THEN
    SELECT lower(trim(email)) INTO v_email FROM technicians WHERE id = v_tid;
  END IF;
  IF v_email IS NULL AND v_pid IS NOT NULL THEN
    SELECT lower(trim(email)) INTO v_email FROM app_people WHERE id = v_pid;
  END IF;
  IF v_name IS NULL THEN
    v_name := coalesce(v_email, 'Unknown');
  END IF;

  INSERT INTO ttb_roster (display_name, email, tech_id, person_id, expected, optional)
  VALUES (v_name, v_email, v_tid, v_pid, NOT coalesce(p_optional, false), coalesce(p_optional, false))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ttb_status_from_join(p_join timestamptz, p_date date)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tz text;
  v_start time;
  v_grace int;
  v_join_local time;
  v_start_min int;
  v_join_min int;
BEGIN
  IF p_join IS NULL THEN
    RETURN 'absent';
  END IF;
  SELECT timezone, start_local, ontime_grace_min
    INTO v_tz, v_start, v_grace
    FROM ttb_settings WHERE id = 1;
  v_join_local := (p_join AT TIME ZONE coalesce(v_tz, 'America/New_York'))::time;
  v_start_min := extract(hour from v_start)::int * 60 + extract(minute from v_start)::int;
  v_join_min := extract(hour from v_join_local)::int * 60 + extract(minute from v_join_local)::int;
  IF v_join_min <= v_start_min + coalesce(v_grace, 5) THEN
    RETURN 'on_time';
  END IF;
  RETURN 'late';
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_ttb_data()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_settings json;
  v_roster json;
  v_sessions json;
  v_attendance json;
  v_topics json;
  v_last json;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT to_json(s) INTO v_settings FROM ttb_settings s WHERE id = 1;
  SELECT coalesce(json_agg(row_to_json(r) ORDER BY r.optional, r.display_name), '[]'::json)
    INTO v_roster
    FROM (
      SELECT id, display_name, email, tech_id, person_id, expected, optional, active
        FROM ttb_roster
       WHERE active = true
    ) r;
  SELECT coalesce(json_agg(row_to_json(s) ORDER BY s.meeting_date), '[]'::json)
    INTO v_sessions
    FROM ttb_sessions s;
  SELECT coalesce(json_agg(row_to_json(a) ORDER BY a.session_id, a.id), '[]'::json)
    INTO v_attendance
    FROM (
      SELECT id, session_id, roster_id, email, display_name, first_join, last_leave,
             duration_seconds, status, informed, notes, source
        FROM ttb_attendance
    ) a;
  SELECT coalesce(json_agg(row_to_json(t) ORDER BY t.kind, t.sort_order, t.id), '[]'::json)
    INTO v_topics
    FROM ttb_topics t;
  SELECT to_json(l) INTO v_last
    FROM ttb_sync_log l
   ORDER BY ran_at DESC
   LIMIT 1;

  RETURN json_build_object(
    'settings', coalesce(v_settings, '{}'::json),
    'roster', v_roster,
    'sessions', v_sessions,
    'attendance', v_attendance,
    'topics', v_topics,
    'last_sync', v_last
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_ttb_save_settings(
  p_organizer_email text,
  p_meeting_join_url text DEFAULT NULL,
  p_start_local time DEFAULT NULL,
  p_ontime_grace_min int DEFAULT NULL,
  p_late_cutoff_min int DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  INSERT INTO ttb_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
  UPDATE ttb_settings SET
    organizer_email = nullif(lower(trim(coalesce(p_organizer_email, ''))), ''),
    meeting_join_url = COALESCE(nullif(trim(p_meeting_join_url), ''), meeting_join_url),
    start_local = COALESCE(p_start_local, start_local),
    ontime_grace_min = COALESCE(p_ontime_grace_min, ontime_grace_min),
    late_cutoff_min = COALESCE(p_late_cutoff_min, late_cutoff_min),
    updated_at = now()
  WHERE id = 1;
  RETURN app_admin_ttb_data();
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_ttb_upsert_topic(
  p_id bigint,
  p_kind text,
  p_occurred_on text,
  p_body text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_kind text := lower(trim(coalesce(p_kind, 'content')));
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_kind NOT IN ('content','decision') THEN
    v_kind := 'content';
  END IF;
  IF p_id IS NOT NULL THEN
    UPDATE ttb_topics
       SET kind = v_kind,
           occurred_on = nullif(trim(coalesce(p_occurred_on, '')), ''),
           body = trim(p_body)
     WHERE id = p_id;
  ELSE
    INSERT INTO ttb_topics (kind, occurred_on, body, sort_order)
    VALUES (v_kind, nullif(trim(coalesce(p_occurred_on, '')), ''), trim(p_body),
            coalesce((SELECT max(sort_order)+1 FROM ttb_topics), 1));
  END IF;
  RETURN app_admin_ttb_data();
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_ttb_delete_topic(p_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM ttb_topics WHERE id = p_id;
  RETURN app_admin_ttb_data();
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_ttb_set_cell(
  p_session_id bigint,
  p_roster_id bigint,
  p_status text,
  p_notes text DEFAULT NULL,
  p_informed boolean DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_status text := lower(trim(coalesce(p_status, '')));
  v_name text;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_status NOT IN ('on_time','late','absent','excused') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;
  SELECT display_name INTO v_name FROM ttb_roster WHERE id = p_roster_id;
  INSERT INTO ttb_attendance (session_id, roster_id, display_name, status, notes, informed, source)
  VALUES (p_session_id, p_roster_id, v_name, v_status, p_notes, coalesce(p_informed, false), 'manual')
  ON CONFLICT (session_id, roster_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    notes = COALESCE(EXCLUDED.notes, ttb_attendance.notes),
    informed = COALESCE(p_informed, ttb_attendance.informed),
    source = 'manual',
    updated_at = now();
  RETURN app_admin_ttb_data();
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_ttb_set_session(
  p_meeting_date date,
  p_cancelled boolean DEFAULT NULL,
  p_topic text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  INSERT INTO ttb_sessions (meeting_date, cancelled, topic)
  VALUES (p_meeting_date, coalesce(p_cancelled, false), nullif(trim(coalesce(p_topic, '')), ''))
  ON CONFLICT (meeting_date) DO UPDATE SET
    cancelled = COALESCE(p_cancelled, ttb_sessions.cancelled),
    topic = COALESCE(nullif(trim(coalesce(p_topic, '')), ''), ttb_sessions.topic);
  RETURN app_admin_ttb_data();
END;
$$;

-- Admin import of the existing TTB workbook / a Teams CSV already parsed in the browser.
CREATE OR REPLACE FUNCTION public.app_admin_ttb_import_sheet(p_payload jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  r jsonb;
  v_sid bigint;
  v_rid bigint;
  v_date date;
  v_join timestamptz;
  v_status text;
  v_optional boolean;
  v_sessions int := 0;
  v_cells int := 0;
  v_topics int := 0;
  v_tz text;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT timezone INTO v_tz FROM ttb_settings WHERE id = 1;
  v_tz := coalesce(v_tz, 'America/New_York');

  FOR r IN SELECT value FROM jsonb_array_elements(coalesce(p_payload->'roster', '[]'::jsonb))
  LOOP
    PERFORM ttb_ensure_roster(r->>'name', r->>'email', coalesce((r->>'optional')::boolean, false));
  END LOOP;

  FOR r IN SELECT value FROM jsonb_array_elements(coalesce(p_payload->'sessions', '[]'::jsonb))
  LOOP
    v_date := (r->>'date')::date;
    IF v_date IS NULL THEN CONTINUE; END IF;
    INSERT INTO ttb_sessions (meeting_date, cancelled, topic)
    VALUES (v_date, coalesce((r->>'cancelled')::boolean, false), nullif(trim(coalesce(r->>'topic','')), ''))
    ON CONFLICT (meeting_date) DO UPDATE SET
      cancelled = EXCLUDED.cancelled,
      topic = COALESCE(EXCLUDED.topic, ttb_sessions.topic);
    v_sessions := v_sessions + 1;
  END LOOP;

  FOR r IN SELECT value FROM jsonb_array_elements(coalesce(p_payload->'cells', '[]'::jsonb))
  LOOP
    v_date := (r->>'date')::date;
    IF v_date IS NULL THEN CONTINUE; END IF;
    SELECT id INTO v_sid FROM ttb_sessions WHERE meeting_date = v_date;
    IF v_sid IS NULL THEN
      INSERT INTO ttb_sessions (meeting_date) VALUES (v_date) RETURNING id INTO v_sid;
    END IF;
    v_optional := coalesce((r->>'optional')::boolean, false);
    v_rid := ttb_ensure_roster(r->>'name', r->>'email', v_optional);
    v_join := NULL;
    IF nullif(trim(coalesce(r->>'first_join','')), '') IS NOT NULL THEN
      v_join := (trim(r->>'first_join'))::timestamptz;
    ELSIF nullif(trim(coalesce(r->>'join_local','')), '') IS NOT NULL THEN
      v_join := ((v_date::text || ' ' || trim(r->>'join_local'))::timestamp AT TIME ZONE v_tz);
    END IF;
    IF coalesce((r->>'absent')::boolean, false) AND v_join IS NULL THEN
      v_status := CASE WHEN coalesce((r->>'informed')::boolean, false) THEN 'excused' ELSE 'absent' END;
    ELSE
      v_status := coalesce(nullif(trim(coalesce(r->>'status','')), ''), ttb_status_from_join(v_join, v_date));
    END IF;
    INSERT INTO ttb_attendance (
      session_id, roster_id, email, display_name, first_join, last_leave,
      duration_seconds, status, informed, notes, source
    )
    VALUES (
      v_sid, v_rid,
      nullif(lower(trim(coalesce(r->>'email',''))), ''),
      coalesce(nullif(trim(coalesce(r->>'name','')), ''), (SELECT display_name FROM ttb_roster WHERE id = v_rid)),
      v_join,
      CASE WHEN nullif(trim(coalesce(r->>'last_leave','')), '') IS NOT NULL
           THEN (trim(r->>'last_leave'))::timestamptz ELSE NULL END,
      NULLIF(r->>'duration_seconds','')::int,
      v_status,
      coalesce((r->>'informed')::boolean, false),
      nullif(trim(coalesce(r->>'notes','')), ''),
      coalesce(nullif(trim(coalesce(r->>'source','')), ''), 'sheet')
    )
    ON CONFLICT (session_id, roster_id)
    DO UPDATE SET
      email = COALESCE(EXCLUDED.email, ttb_attendance.email),
      first_join = COALESCE(EXCLUDED.first_join, ttb_attendance.first_join),
      last_leave = COALESCE(EXCLUDED.last_leave, ttb_attendance.last_leave),
      duration_seconds = COALESCE(EXCLUDED.duration_seconds, ttb_attendance.duration_seconds),
      status = EXCLUDED.status,
      informed = EXCLUDED.informed,
      notes = COALESCE(EXCLUDED.notes, ttb_attendance.notes),
      source = EXCLUDED.source,
      updated_at = now();
    v_cells := v_cells + 1;
  END LOOP;

  FOR r IN SELECT value FROM jsonb_array_elements(coalesce(p_payload->'topics', '[]'::jsonb))
  LOOP
    IF nullif(trim(coalesce(r->>'body','')), '') IS NULL THEN CONTINUE; END IF;
    IF EXISTS (
      SELECT 1 FROM ttb_topics
       WHERE kind = coalesce(nullif(trim(coalesce(r->>'kind','')), ''), 'content')
         AND coalesce(occurred_on,'') = coalesce(trim(coalesce(r->>'occurred_on','')), '')
         AND body = trim(r->>'body')
    ) THEN
      CONTINUE;
    END IF;
    INSERT INTO ttb_topics (kind, occurred_on, body, sort_order)
    VALUES (
      CASE WHEN lower(trim(coalesce(r->>'kind',''))) = 'decision' THEN 'decision' ELSE 'content' END,
      nullif(trim(coalesce(r->>'occurred_on','')), ''),
      trim(r->>'body'),
      coalesce((SELECT max(sort_order)+1 FROM ttb_topics), 1)
    );
    v_topics := v_topics + 1;
  END LOOP;

  INSERT INTO ttb_sync_log (meeting_date, matched, unmatched, absent, detail)
  VALUES (
    NULL, v_cells, 0, 0,
    json_build_object('source', 'sheet', 'sessions', v_sessions, 'topics', v_topics)
  );

  RETURN json_build_object('ok', true, 'sessions', v_sessions, 'cells', v_cells, 'topics', v_topics, 'data', app_admin_ttb_data());
END;
$$;

-- Netlify Graph sync writes through the shared ATA webhook secret.
CREATE OR REPLACE FUNCTION public.app_ttb_import_attendance(p_secret text, p_session jsonb, p_rows jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret text;
  v_date date;
  v_sid bigint;
  r jsonb;
  v_rid bigint;
  v_email text;
  v_name text;
  v_join timestamptz;
  v_status text;
  v_matched int := 0;
  v_unmatch int := 0;
  v_absent int := 0;
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  v_date := (p_session->>'meeting_date')::date;
  IF v_date IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'missing_meeting_date');
  END IF;

  INSERT INTO ttb_sessions (meeting_date, cancelled, topic, teams_meeting_id, teams_report_id, synced_at)
  VALUES (
    v_date,
    coalesce((p_session->>'cancelled')::boolean, false),
    nullif(trim(coalesce(p_session->>'topic','')), ''),
    nullif(trim(coalesce(p_session->>'teams_meeting_id','')), ''),
    nullif(trim(coalesce(p_session->>'teams_report_id','')), ''),
    now()
  )
  ON CONFLICT (meeting_date) DO UPDATE SET
    teams_meeting_id = COALESCE(EXCLUDED.teams_meeting_id, ttb_sessions.teams_meeting_id),
    teams_report_id = COALESCE(EXCLUDED.teams_report_id, ttb_sessions.teams_report_id),
    topic = COALESCE(EXCLUDED.topic, ttb_sessions.topic),
    synced_at = now()
  RETURNING id INTO v_sid;

  FOR r IN SELECT value FROM jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
  LOOP
    v_email := nullif(lower(trim(coalesce(r->>'email',''))), '');
    v_name := nullif(trim(coalesce(r->>'name','')), '');
    v_join := NULLIF(trim(coalesce(r->>'first_join','')), '')::timestamptz;
    v_rid := ttb_match_roster(v_email, v_name);
    IF v_rid IS NULL THEN
      v_rid := ttb_ensure_roster(v_name, v_email, false);
    END IF;
    IF v_rid IS NULL THEN
      v_unmatch := v_unmatch + 1;
      v_status := 'unmatched';
    ELSE
      v_matched := v_matched + 1;
      v_status := ttb_status_from_join(v_join, v_date);
    END IF;

    INSERT INTO ttb_attendance (
      session_id, roster_id, email, display_name, first_join, last_leave,
      duration_seconds, status, source
    )
    VALUES (
      v_sid, v_rid, v_email, v_name, v_join,
      NULLIF(trim(coalesce(r->>'last_leave','')), '')::timestamptz,
      NULLIF(r->>'duration_seconds','')::int,
      v_status, 'teams'
    )
    ON CONFLICT (session_id, roster_id)
    DO UPDATE SET
      email = COALESCE(EXCLUDED.email, ttb_attendance.email),
      display_name = COALESCE(EXCLUDED.display_name, ttb_attendance.display_name),
      first_join = EXCLUDED.first_join,
      last_leave = EXCLUDED.last_leave,
      duration_seconds = EXCLUDED.duration_seconds,
      status = CASE WHEN ttb_attendance.source = 'manual' AND ttb_attendance.status IN ('excused','absent')
                    AND EXCLUDED.first_join IS NULL
                    THEN ttb_attendance.status
                    ELSE EXCLUDED.status END,
      source = CASE WHEN ttb_attendance.source = 'manual' AND ttb_attendance.status IN ('excused')
                    THEN ttb_attendance.source ELSE 'teams' END,
      updated_at = now();
  END LOOP;

  INSERT INTO ttb_attendance (session_id, roster_id, display_name, email, status, source)
  SELECT v_sid, r.id, r.display_name, r.email, 'absent', 'teams'
    FROM ttb_roster r
   WHERE r.active AND r.expected AND NOT r.optional
     AND NOT EXISTS (
       SELECT 1 FROM ttb_attendance a
        WHERE a.session_id = v_sid AND a.roster_id = r.id
     );
  GET DIAGNOSTICS v_absent = ROW_COUNT;

  INSERT INTO ttb_sync_log (meeting_date, matched, unmatched, absent, detail)
  VALUES (v_date, v_matched, v_unmatch, v_absent, p_session);

  RETURN json_build_object(
    'ok', true,
    'session_id', v_sid,
    'meeting_date', v_date,
    'matched', v_matched,
    'unmatched', v_unmatch,
    'absent', v_absent
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ttb_norm_name(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ttb_match_roster(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ttb_ensure_roster(text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ttb_status_from_join(timestamptz, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_save_settings(text, text, time, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_upsert_topic(bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_delete_topic(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_set_cell(bigint, bigint, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_set_session(date, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_ttb_import_sheet(jsonb) TO authenticated;
CREATE OR REPLACE FUNCTION public.app_ttb_settings(p_secret text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret text;
  v_row ttb_settings%ROWTYPE;
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;
  SELECT * INTO v_row FROM ttb_settings WHERE id = 1;
  RETURN json_build_object(
    'ok', true,
    'organizer_email', v_row.organizer_email,
    'meeting_join_url', v_row.meeting_join_url
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_ttb_import_attendance(text, jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ttb_settings(text) TO anon, authenticated;
