-- PM NEBB CT report: region-scoped roster + save/upload/view cert PDFs.
-- Safe to re-run.

DROP FUNCTION IF EXISTS public.app_admin_save_nebb_report_row(bigint, text, boolean, boolean);
DROP FUNCTION IF EXISTS public.app_admin_save_cert_pdf(bigint, text, text);
DROP FUNCTION IF EXISTS public.app_admin_get_cert_pdf(bigint);

CREATE OR REPLACE FUNCTION public.app_pm_session_region(p_token text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT s.region
  FROM public.sessions s
  WHERE s.token = p_token
    AND s.expires_at > now()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.app_person_effective_region(p_person_id bigint)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT coalesce(
    CASE WHEN p.role = 'technician' THEN t.region ELSE p.region END,
    ''
  )
  FROM public.app_people p
  LEFT JOIN public.technicians t ON t.id = p.tech_id
  WHERE p.id = p_person_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.app_pm_can_manage_nebb_person(p_person_id bigint, p_token text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_sess_region text;
  v_person_region text;
BEGIN
  IF app_is_admin() THEN
    RETURN true;
  END IF;
  IF p_person_id IS NULL OR p_token IS NULL OR trim(p_token) = '' THEN
    RETURN false;
  END IF;
  v_sess_region := app_pm_session_region(p_token);
  IF v_sess_region IS NULL THEN
    RETURN false;
  END IF;
  IF v_sess_region = 'ALL' THEN
    RETURN true;
  END IF;
  v_person_region := app_person_effective_region(p_person_id);
  RETURN v_person_region IS NOT NULL AND v_person_region = v_sess_region;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_pm_nebb_certified_report(p_token text)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text := app_pm_session_region(p_token);
  v_result json;
BEGIN
  IF v_region IS NULL THEN
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
      AND (
        v_region = 'ALL'
        OR coalesce(CASE WHEN p.role='technician' THEN t.region ELSE p.region END, '') = v_region
      )
  ) x;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_save_nebb_report_row(
  p_person_id bigint,
  p_cert_expires_on text DEFAULT NULL,
  p_cecs_complete boolean DEFAULT NULL,
  p_nebb_site_updated boolean DEFAULT NULL,
  p_token text DEFAULT NULL
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
  IF NOT app_is_admin() AND NOT app_pm_can_manage_nebb_person(p_person_id, p_token) THEN
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

CREATE OR REPLACE FUNCTION public.app_admin_save_cert_pdf(
  p_person_id bigint,
  p_file_name text,
  p_content_base64 text,
  p_token text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT app_is_admin() AND NOT app_pm_can_manage_nebb_person(p_person_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_person_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.app_people WHERE id = p_person_id) THEN
    RAISE EXCEPTION 'Person not found';
  END IF;
  IF p_content_base64 IS NULL OR trim(p_content_base64) = '' THEN
    RAISE EXCEPTION 'PDF content is required';
  END IF;
  IF length(p_content_base64) > 12000000 THEN
    RAISE EXCEPTION 'PDF is too large';
  END IF;
  IF lower(coalesce(p_file_name,'')) !~ '\.pdf$' THEN
    RAISE EXCEPTION 'Only PDF files are allowed';
  END IF;
  IF left(regexp_replace(trim(p_content_base64), '\s', '', 'g'), 5) NOT IN ('JVBER') THEN
    RAISE EXCEPTION 'Only valid PDF files are allowed';
  END IF;

  INSERT INTO public.app_person_cert_files (person_id, file_name, mime_type, content_base64, updated_at)
  VALUES (
    p_person_id,
    COALESCE(NULLIF(trim(p_file_name), ''), 'certification.pdf'),
    'application/pdf',
    p_content_base64,
    now()
  )
  ON CONFLICT (person_id) DO UPDATE
    SET file_name      = EXCLUDED.file_name,
        mime_type      = EXCLUDED.mime_type,
        content_base64 = EXCLUDED.content_base64,
        updated_at     = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_get_cert_pdf(
  p_person_id bigint,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT app_is_admin() AND NOT app_pm_can_manage_nebb_person(p_person_id, p_token) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT row_to_json(x)
  INTO v_result
  FROM (
    SELECT
      f.person_id,
      f.file_name,
      f.mime_type,
      f.content_base64,
      f.updated_at
    FROM public.app_person_cert_files f
    WHERE f.person_id = p_person_id
  ) x;

  RETURN COALESCE(v_result, '{}'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_pm_session_region(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_person_effective_region(bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_can_manage_nebb_person(bigint, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_pm_nebb_certified_report(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_save_nebb_report_row(bigint, text, boolean, boolean, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_save_cert_pdf(bigint, text, text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_get_cert_pdf(bigint, text) TO authenticated, anon;
