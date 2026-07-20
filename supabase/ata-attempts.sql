-- ATA Tracking — per-attempt tracking, pass/fail (>=80%), and monthly reset limit.
-- Run in Supabase → SQL Editor AFTER supabase/ata-tracking.sql.
--
-- What this adds:
--   * ata_attempts        — one row per Teachable quiz submission (each retake is a
--                           new row), so we can count attempts/resets per month.
--   * ata_completions.passed — a lesson counts as "done" only when scored >= 80%.
--   * app_ata_record_attempt — the endpoint Zapier POSTs to on every Teachable quiz
--                           result. Secret-gated so only your Zap can write.
--   * ata_secrets         — holds the shared webhook secret (not readable by anon).
--   * app_ata_webhook_secret — admin-only helper to read the secret for the UI.
--   * Roster/tech RPCs re-defined to also return a per-lesson attempts summary.
--
-- Business rules (computed in the browser from this data):
--   * Pass threshold: score_percent >= 80.
--   * Resets used this month (per lesson) = attempts this month - 1 (min 0).
--   * Max 3 resets per lesson per month; a 4th requires a call with Brenda.

-- ── Attempts + pass flag ─────────────────────────────────────────────────────
ALTER TABLE public.ata_completions ADD COLUMN IF NOT EXISTS passed boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.ata_attempts (
  id            bigserial PRIMARY KEY,
  tech_id       bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  lesson_code   text NOT NULL,
  score_percent numeric,
  passed        boolean NOT NULL DEFAULT false,
  attempted_at  timestamptz NOT NULL DEFAULT now(),
  source        text,
  external_id   text,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ata_attempts_tech_idx ON public.ata_attempts (tech_id, lesson_code);
CREATE INDEX IF NOT EXISTS ata_attempts_when_idx ON public.ata_attempts (attempted_at);
-- Idempotency: if Zapier resends the same Teachable response, don't double-count.
CREATE UNIQUE INDEX IF NOT EXISTS ata_attempts_external_uidx
  ON public.ata_attempts (external_id) WHERE external_id IS NOT NULL;

-- ── Shared webhook secret ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ata_secrets (
  name   text PRIMARY KEY,
  secret text NOT NULL
);
-- Seed a random 64-char secret once (uses core gen_random_uuid, no extension needed).
INSERT INTO public.ata_secrets (name, secret)
VALUES ('webhook', replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-',''))
ON CONFLICT (name) DO NOTHING;

-- Admin-only: read the secret so the UI can show the Zapier setup details.
CREATE OR REPLACE FUNCTION public.app_ata_webhook_secret()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN (SELECT secret FROM ata_secrets WHERE name = 'webhook');
END;
$$;

-- ── The endpoint Zapier calls on every Teachable quiz result ──────────────────
-- Zapier "Webhooks by Zapier → POST" to:
--   {SUPABASE_URL}/rest/v1/rpc/app_ata_record_attempt
-- Headers: apikey + Authorization: Bearer {anon key}, Content-Type: application/json
-- Body (JSON): {
--   "p_secret": "<the webhook secret>",
--   "p_email": "{{student email}}",
--   "p_name":  "{{student name}}",
--   "p_lesson_code": "{{quiz name}}",   -- must contain a code like TAB-B-101
--   "p_score": {{percent 0-100}},        -- OR send p_correct + p_total instead
--   "p_correct": {{correct}},
--   "p_total": {{total}},
--   "p_attempted_at": "{{submitted at ISO8601}}",
--   "p_external_id": "{{response id}}"
-- }
CREATE OR REPLACE FUNCTION public.app_ata_record_attempt(
  p_secret       text,
  p_email        text DEFAULT NULL,
  p_name         text DEFAULT NULL,
  p_lesson_code  text DEFAULT NULL,
  p_score        numeric DEFAULT NULL,
  p_correct      numeric DEFAULT NULL,
  p_total        numeric DEFAULT NULL,
  p_attempted_at timestamptz DEFAULT NULL,
  p_external_id  text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_secret  text;
  v_email   text := lower(trim(coalesce(p_email,'')));
  v_name    text := lower(trim(coalesce(p_name,'')));
  v_code    text := upper(trim(coalesce(p_lesson_code,'')));
  v_tid     bigint;
  v_score   numeric;
  v_passed  boolean;
  v_at      timestamptz := coalesce(p_attempted_at, now());
BEGIN
  SELECT secret INTO v_secret FROM ata_secrets WHERE name = 'webhook';
  IF v_secret IS NULL OR p_secret IS NULL OR p_secret <> v_secret THEN
    RETURN json_build_object('ok', false, 'error', 'unauthorized');
  END IF;

  IF v_code !~ 'TAB-[BIA]-[0-9]+' THEN
    RETURN json_build_object('ok', false, 'error', 'no_lesson_code');
  END IF;
  v_code := (regexp_match(v_code, '(TAB-[BIA]-[0-9]+)'))[1];

  -- Compute percent from either a direct percent or correct/total.
  IF p_score IS NOT NULL THEN
    v_score := CASE WHEN p_score <= 1 AND p_score > 0 THEN p_score * 100 ELSE p_score END;
  ELSIF p_total IS NOT NULL AND p_total > 0 THEN
    v_score := round((coalesce(p_correct,0) / p_total) * 1000) / 10;
  ELSE
    v_score := NULL;
  END IF;
  v_passed := v_score IS NOT NULL AND v_score >= 80;

  -- Match a technician by email first, then by name.
  IF v_email <> '' THEN
    SELECT id INTO v_tid FROM technicians
    WHERE email IS NOT NULL AND lower(trim(email)) = v_email AND deleted_at IS NULL LIMIT 1;
  END IF;
  IF v_tid IS NULL AND v_name <> '' THEN
    SELECT id INTO v_tid FROM technicians
    WHERE lower(trim(name)) = v_name AND deleted_at IS NULL LIMIT 1;
  END IF;
  IF v_tid IS NULL THEN
    RETURN json_build_object('ok', false, 'error', 'no_tech', 'email', v_email, 'name', v_name);
  END IF;

  -- Record the attempt (idempotent on external_id).
  INSERT INTO ata_attempts (tech_id, lesson_code, score_percent, passed, attempted_at, source, external_id)
  VALUES (v_tid, v_code, v_score, v_passed, v_at, 'zapier', nullif(p_external_id,''))
  ON CONFLICT (external_id) WHERE external_id IS NOT NULL DO UPDATE
    SET tech_id = EXCLUDED.tech_id,
        lesson_code = EXCLUDED.lesson_code,
        score_percent = EXCLUDED.score_percent,
        passed = EXCLUDED.passed,
        attempted_at = EXCLUDED.attempted_at;

  -- Roll up into completions: keep the best score; mark done once passed.
  INSERT INTO ata_completions (tech_id, lesson_code, score_percent, completed_at, passed, source_email, updated_at)
  VALUES (v_tid, v_code, v_score, CASE WHEN v_passed THEN v_at END, v_passed, nullif(v_email,''), now())
  ON CONFLICT (tech_id, lesson_code) DO UPDATE
    SET score_percent = GREATEST(coalesce(ata_completions.score_percent, 0), coalesce(EXCLUDED.score_percent, 0)),
        passed        = ata_completions.passed OR EXCLUDED.passed,
        completed_at  = coalesce(ata_completions.completed_at, EXCLUDED.completed_at),
        source_email  = coalesce(EXCLUDED.source_email, ata_completions.source_email),
        updated_at    = now();

  RETURN json_build_object('ok', true, 'tech_id', v_tid, 'lesson_code', v_code, 'score', v_score, 'passed', v_passed);
END;
$$;

-- ── Roster JSON (now includes a per-lesson attempts summary + passed flag) ─────
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
          (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
             FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
          (SELECT coalesce(json_object_agg(c.lesson_code,
             json_build_object('score', c.score_percent, 'completed_at', c.completed_at, 'passed', c.passed)), '{}'::json)
             FROM ata_completions c WHERE c.tech_id = t.id) AS completions,
          (SELECT coalesce(json_object_agg(s.lesson_code, s.info), '{}'::json) FROM (
             SELECT lesson_code, json_build_object(
               'count', count(*),
               'best', max(score_percent),
               'passed', bool_or(coalesce(passed,false)),
               'last_at', max(attempted_at),
               'last_score', (array_agg(score_percent ORDER BY attempted_at DESC))[1],
               'month_count', count(*) FILTER (WHERE attempted_at >= date_trunc('month', now()))
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

-- ── Single technician (now includes attempts + passed) ────────────────────────
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
      (SELECT coalesce(json_object_agg(ps.program, ps.start_date), '{}'::json)
         FROM ata_program_starts ps WHERE ps.tech_id = t.id AND ps.start_date IS NOT NULL) AS starts,
      (SELECT coalesce(json_object_agg(c.lesson_code,
         json_build_object('score', c.score_percent, 'completed_at', c.completed_at, 'passed', c.passed)), '{}'::json)
         FROM ata_completions c WHERE c.tech_id = t.id) AS completions,
      (SELECT coalesce(json_object_agg(s.lesson_code, s.info), '{}'::json) FROM (
         SELECT lesson_code, json_build_object(
           'count', count(*),
           'best', max(score_percent),
           'passed', bool_or(coalesce(passed,false)),
           'last_at', max(attempted_at),
           'last_score', (array_agg(score_percent ORDER BY attempted_at DESC))[1],
           'month_count', count(*) FILTER (WHERE attempted_at >= date_trunc('month', now()))
         ) AS info
         FROM ata_attempts WHERE tech_id = t.id GROUP BY lesson_code
      ) s) AS attempts
    FROM technicians t
    WHERE t.id = v_tech_id AND t.deleted_at IS NULL
  ) x;

  RETURN v_tech;
END;
$$;

-- ── Grants ───────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.app_ata_record_attempt(text,text,text,text,numeric,numeric,numeric,timestamptz,text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_webhook_secret()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_roster_json(text)                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_ata_tech_data(text)                           TO anon, authenticated;
