-- Training Focus: goal text + start/end dates for technicians.
-- Safe to re-run.

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS training_focus text,
  ADD COLUMN IF NOT EXISTS training_goal_start date,
  ADD COLUMN IF NOT EXISTS training_goal_end date;

DROP FUNCTION IF EXISTS public.app_admin_list_people();

CREATE OR REPLACE FUNCTION public.app_admin_list_people()
RETURNS TABLE (
  id bigint,
  email text,
  full_name text,
  role text,
  region text,
  deleted boolean,
  tech_id bigint,
  nebb_status text,
  cert_expires_on date,
  cecs_complete boolean,
  nebb_site_updated boolean,
  start_date date,
  bootcamp_start_date date,
  latest_raw_scores jsonb,
  required_categories jsonb,
  training_focus text,
  training_goal_start date,
  training_goal_end date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_join text := app_assessment_join_sql('a', 't.id');
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY EXECUTE format($q$
    SELECT p.id,
           p.email,
           COALESCE(p.full_name, t.name) AS full_name,
           p.role,
           CASE WHEN p.role='technician' THEN t.region ELSE p.region END AS region,
           (t.deleted_at IS NOT NULL) AS deleted,
           p.tech_id,
           CASE WHEN p.role='technician' THEN t.nebb_status ELSE p.nebb_status END AS nebb_status,
           CASE WHEN p.role='technician' THEN t.cert_expires_on ELSE p.cert_expires_on END AS cert_expires_on,
           CASE WHEN p.role='technician' THEN coalesce(t.cecs_complete,false) ELSE coalesce(p.cecs_complete,false) END AS cecs_complete,
           CASE WHEN p.role='technician' THEN coalesce(t.nebb_site_updated,false) ELSE coalesce(p.nebb_site_updated,false) END AS nebb_site_updated,
           t.start_date,
           t.bootcamp_start_date,
           (
             SELECT a.raw_scores::jsonb
             FROM public.assessments a
             WHERE %s
               AND a.raw_scores IS NOT NULL
               AND a.raw_scores::jsonb <> '{}'::jsonb
             ORDER BY a.date DESC
             LIMIT 1
           ) AS latest_raw_scores,
           t.required_categories,
           t.training_focus,
           t.training_goal_start,
           t.training_goal_end
    FROM public.app_people p
    LEFT JOIN public.technicians t ON t.id = p.tech_id
    ORDER BY
      CASE p.role WHEN 'admin' THEN 1 WHEN 'pm' THEN 2 ELSE 3 END,
      (t.deleted_at IS NOT NULL),
      lower(COALESCE(p.full_name, t.name, p.email))
  $q$, v_join);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_people() TO authenticated;

DROP FUNCTION IF EXISTS public.app_admin_update_person(bigint, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.app_admin_update_person(bigint, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.app_admin_update_person(bigint, text, text, text, text, text, text, text, text, boolean);
DROP FUNCTION IF EXISTS public.app_admin_update_person(bigint, text, text, text, text, text, text, text, text, boolean, boolean);
DROP FUNCTION IF EXISTS public.app_admin_update_person(bigint, text, text, text, text, text, text, text, text, boolean, boolean, jsonb);

CREATE OR REPLACE FUNCTION public.app_admin_update_person(
  p_id         bigint,
  p_name       text DEFAULT NULL,
  p_email      text DEFAULT NULL,
  p_role       text DEFAULT NULL,
  p_region     text DEFAULT NULL,
  p_start_date text DEFAULT NULL,
  p_bootcamp_start_date text DEFAULT NULL,
  p_nebb_status text DEFAULT NULL,
  p_cert_expires_on text DEFAULT NULL,
  p_cecs_complete boolean DEFAULT NULL,
  p_nebb_site_updated boolean DEFAULT NULL,
  p_required_categories jsonb DEFAULT NULL,
  p_training_focus text DEFAULT NULL,
  p_training_goal_start text DEFAULT NULL,
  p_training_goal_end text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_role        text;
  v_tech_id     bigint;
  v_email       text;
  v_new_email   text := lower(trim(p_email));
  v_me          text := app_current_email();
  v_admin_count int;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT role, tech_id, email INTO v_role, v_tech_id, v_email
  FROM public.app_people WHERE id = p_id;
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Person not found';
  END IF;

  UPDATE public.app_people
  SET full_name = COALESCE(NULLIF(trim(p_name), ''), full_name)
  WHERE id = p_id;

  IF v_new_email IS NOT NULL AND v_new_email <> '' AND v_new_email <> v_email THEN
    IF NOT app_allowed_email(v_new_email) THEN
      RAISE EXCEPTION 'Email domain is not allowed';
    END IF;
    IF EXISTS (SELECT 1 FROM public.app_people WHERE email = v_new_email AND id <> p_id) THEN
      RAISE EXCEPTION 'That email is already in use';
    END IF;
    UPDATE public.app_people SET email = v_new_email WHERE id = p_id;
    IF v_tech_id IS NOT NULL THEN
      UPDATE public.technicians SET email = v_new_email WHERE id = v_tech_id;
    END IF;
  END IF;

  IF p_role IS NOT NULL AND p_role IN ('admin','pm')
     AND v_role IN ('admin','pm') AND p_role <> v_role THEN
    IF v_role = 'admin' AND p_role <> 'admin' THEN
      IF v_email = v_me THEN
        RAISE EXCEPTION 'You cannot change your own admin role';
      END IF;
      SELECT count(*) INTO v_admin_count FROM public.app_people WHERE role = 'admin';
      IF v_admin_count <= 1 THEN
        RAISE EXCEPTION 'Cannot remove the last admin';
      END IF;
    END IF;
    UPDATE public.app_people SET role = p_role WHERE id = p_id;
  END IF;

  IF v_role IN ('admin','pm') THEN
    UPDATE public.app_people
    SET region = CASE
                   WHEN p_region IS NULL THEN region
                   WHEN trim(p_region) = '' THEN NULL
                   ELSE p_region
                 END,
        nebb_status = CASE
                        WHEN p_nebb_status IS NULL THEN nebb_status
                        WHEN trim(p_nebb_status) = '' THEN NULL
                        ELSE p_nebb_status
                      END,
        cert_expires_on = CASE
                            WHEN p_cert_expires_on IS NULL THEN cert_expires_on
                            WHEN trim(p_cert_expires_on) = '' THEN NULL
                            ELSE p_cert_expires_on::date
                          END,
        cecs_complete = COALESCE(p_cecs_complete, cecs_complete),
        nebb_site_updated = COALESCE(p_nebb_site_updated, nebb_site_updated)
    WHERE id = p_id;
  END IF;

  IF v_role = 'technician' AND v_tech_id IS NOT NULL THEN
    UPDATE public.technicians
    SET region = CASE WHEN p_region IS NOT NULL AND trim(p_region) <> '' THEN p_region ELSE region END,
        name   = COALESCE(NULLIF(trim(p_name), ''), name),
        start_date = CASE
          WHEN p_start_date IS NULL THEN start_date
          WHEN trim(p_start_date) = '' THEN NULL
          ELSE p_start_date::date
        END,
        bootcamp_start_date = CASE
          WHEN p_bootcamp_start_date IS NULL THEN bootcamp_start_date
          WHEN trim(p_bootcamp_start_date) = '' THEN NULL
          ELSE p_bootcamp_start_date::date
        END,
        nebb_status = CASE
          WHEN p_nebb_status IS NULL THEN nebb_status
          WHEN trim(p_nebb_status) = '' THEN NULL
          ELSE p_nebb_status
        END,
        cert_expires_on = CASE
          WHEN p_cert_expires_on IS NULL THEN cert_expires_on
          WHEN trim(p_cert_expires_on) = '' THEN NULL
          ELSE p_cert_expires_on::date
        END,
        cecs_complete = COALESCE(p_cecs_complete, cecs_complete),
        nebb_site_updated = COALESCE(p_nebb_site_updated, nebb_site_updated),
        required_categories = CASE
          WHEN p_required_categories IS NULL THEN required_categories
          WHEN jsonb_typeof(p_required_categories) = 'array' THEN p_required_categories
          ELSE required_categories
        END,
        training_focus = CASE
          WHEN p_training_focus IS NULL THEN training_focus
          ELSE NULLIF(trim(p_training_focus), '')
        END,
        training_goal_start = CASE
          WHEN p_training_goal_start IS NULL THEN training_goal_start
          WHEN trim(p_training_goal_start) = '' THEN NULL
          ELSE p_training_goal_start::date
        END,
        training_goal_end = CASE
          WHEN p_training_goal_end IS NULL THEN training_goal_end
          WHEN trim(p_training_goal_end) = '' THEN NULL
          ELSE p_training_goal_end::date
        END
    WHERE id = v_tech_id AND deleted_at IS NULL;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_update_person(bigint, text, text, text, text, text, text, text, text, boolean, boolean, jsonb, text, text, text) TO authenticated;
