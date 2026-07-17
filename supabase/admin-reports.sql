-- Admin reports for TAB Skills Tracker
-- Run in Supabase -> SQL Editor AFTER supabase/admin.sql and assessments-rpcs.sql.
-- Safe to re-run (CREATE OR REPLACE).

-- ── Technician activity: last update, staleness, skills changed since prior submission ─
CREATE OR REPLACE FUNCTION public.app_admin_technician_activity_report()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_fk_col text;
  v_result json;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_fk_col := app_assessments_fk_col();
  IF v_fk_col IS NULL THEN
    RETURN '[]'::json;
  END IF;

  EXECUTE format($q$
    SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.name, x.region NULLS LAST), '[]'::json)
    FROM (
      SELECT
        t.id AS tech_id,
        t.name,
        t.region,
        l.last_update_date,
        CASE
          WHEN l.last_update_date IS NULL THEN NULL
          ELSE (current_date - l.last_update_date)::int
        END AS days_since_update,
        coalesce(l.assessment_count, 0)::int AS assessment_count,
        CASE
          WHEN coalesce(l.assessment_count, 0) < 2 THEN NULL
          ELSE (
            SELECT count(*)::int
            FROM (
              SELECT keys.key
              FROM (
                SELECT jsonb_object_keys(coalesce(l.latest_raw, '{}'::jsonb)) AS key
                UNION
                SELECT jsonb_object_keys(coalesce(prev.prev_raw, '{}'::jsonb)) AS key
              ) keys
              WHERE coalesce(l.latest_raw -> keys.key, 'null'::jsonb)
                    IS DISTINCT FROM coalesce(prev.prev_raw -> keys.key, 'null'::jsonb)
            ) diff
          )
        END AS skills_changed
      FROM public.technicians t
      JOIN public.app_people p ON p.tech_id = t.id AND p.role = 'technician'
      LEFT JOIN LATERAL (
        SELECT
          r.date AS last_update_date,
          r.raw_scores::jsonb AS latest_raw,
          r.assessment_count
        FROM (
          SELECT
            a.date,
            a.raw_scores,
            row_number() OVER (ORDER BY a.date DESC) AS rn,
            count(*) OVER () AS assessment_count
          FROM public.assessments a
          WHERE a.%1$I = t.id
        ) r
        WHERE r.rn = 1
      ) l ON true
      LEFT JOIN LATERAL (
        SELECT r.raw_scores::jsonb AS prev_raw
        FROM (
          SELECT
            a.raw_scores,
            row_number() OVER (ORDER BY a.date DESC) AS rn
          FROM public.assessments a
          WHERE a.%1$I = t.id
        ) r
        WHERE r.rn = 2
      ) prev ON true
      WHERE t.deleted_at IS NULL
    ) x
  $q$, v_fk_col)
  INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_technician_activity_report() TO authenticated;

-- ── NEBB certified roster (CP/CT only across admins, PMs, technicians) ───────
CREATE OR REPLACE FUNCTION public.app_admin_nebb_certified_report()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.name, x.region NULLS LAST), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      p.id AS person_id,
      coalesce(p.full_name, t.name, p.email) AS name,
      p.role,
      coalesce(CASE WHEN p.role='technician' THEN t.region ELSE p.region END, '') AS region,
      CASE
        WHEN p.role='technician' THEN t.nebb_status
        ELSE p.nebb_status
      END AS nebb_status,
      CASE
        WHEN p.role='technician' THEN t.cert_expires_on
        ELSE p.cert_expires_on
      END AS cert_expires_on,
      CASE
        WHEN p.role='technician' THEN coalesce(t.cecs_complete,false)
        ELSE coalesce(p.cecs_complete,false)
      END AS cecs_complete,
      CASE
        WHEN p.role='technician' THEN coalesce(t.nebb_site_updated,false)
        ELSE coalesce(p.nebb_site_updated,false)
      END AS nebb_site_updated,
      CASE
        WHEN (CASE WHEN p.role='technician' THEN t.cert_expires_on ELSE p.cert_expires_on END) IS NULL THEN NULL
        ELSE ((CASE WHEN p.role='technician' THEN t.cert_expires_on ELSE p.cert_expires_on END) - current_date)::int
      END AS days_until_expiry,
      EXISTS (
        SELECT 1 FROM public.app_person_cert_files f
        WHERE f.person_id = p.id
      ) AS has_cert_file
    FROM public.app_people p
    LEFT JOIN public.technicians t ON t.id = p.tech_id
    WHERE (p.role <> 'technician' OR t.deleted_at IS NULL)
      AND (
        lower(coalesce(CASE WHEN p.role='technician' THEN t.nebb_status ELSE p.nebb_status END,'')) LIKE '%cp%'
        OR lower(coalesce(CASE WHEN p.role='technician' THEN t.nebb_status ELSE p.nebb_status END,'')) LIKE '%ct%'
      )
  ) x;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_nebb_certified_report() TO authenticated;

-- ── NEBB report inline save (expiration + CEC + site-updated flags) ──────────
CREATE OR REPLACE FUNCTION public.app_admin_save_nebb_report_row(
  p_person_id bigint,
  p_cert_expires_on text DEFAULT NULL,
  p_cecs_complete boolean DEFAULT NULL,
  p_nebb_site_updated boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_role    text;
  v_tech_id bigint;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT role, tech_id INTO v_role, v_tech_id
  FROM public.app_people
  WHERE id = p_person_id;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Person not found';
  END IF;

  IF v_role IN ('admin','pm') THEN
    UPDATE public.app_people
    SET cert_expires_on = CASE
                            WHEN p_cert_expires_on IS NULL THEN cert_expires_on
                            WHEN trim(p_cert_expires_on) = '' THEN NULL
                            ELSE p_cert_expires_on::date
                          END,
        cecs_complete = COALESCE(p_cecs_complete, cecs_complete),
        nebb_site_updated = COALESCE(p_nebb_site_updated, nebb_site_updated)
    WHERE id = p_person_id;
  ELSIF v_role = 'technician' AND v_tech_id IS NOT NULL THEN
    UPDATE public.technicians
    SET cert_expires_on = CASE
          WHEN p_cert_expires_on IS NULL THEN cert_expires_on
          WHEN trim(p_cert_expires_on) = '' THEN NULL
          ELSE p_cert_expires_on::date
        END,
        cecs_complete = COALESCE(p_cecs_complete, cecs_complete),
        nebb_site_updated = COALESCE(p_nebb_site_updated, nebb_site_updated)
    WHERE id = v_tech_id AND deleted_at IS NULL;
  ELSE
    RAISE EXCEPTION 'Unable to update this person';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_save_nebb_report_row(bigint, text, boolean, boolean) TO authenticated;
