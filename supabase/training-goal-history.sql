-- Training Goals: admins edit, previous goals are kept.
-- Safe to re-run.

CREATE TABLE IF NOT EXISTS public.training_goal_history (
  id bigserial PRIMARY KEY,
  tech_id bigint NOT NULL REFERENCES public.technicians(id) ON DELETE CASCADE,
  training_focus text,
  training_goal_start date,
  training_goal_end date,
  changed_at timestamptz NOT NULL DEFAULT now(),
  changed_by text
);

CREATE INDEX IF NOT EXISTS training_goal_history_tech_idx
  ON public.training_goal_history (tech_id, changed_at DESC, id DESC);

CREATE OR REPLACE FUNCTION public.training_goals_keep_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_by text;
BEGIN
  IF NEW.training_focus IS NOT DISTINCT FROM OLD.training_focus
     AND NEW.training_goal_start IS NOT DISTINCT FROM OLD.training_goal_start
     AND NEW.training_goal_end IS NOT DISTINCT FROM OLD.training_goal_end THEN
    RETURN NEW;
  END IF;

  IF nullif(trim(coalesce(OLD.training_focus, '')), '') IS NULL
     AND OLD.training_goal_start IS NULL
     AND OLD.training_goal_end IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_by := public.app_current_email();
  EXCEPTION WHEN OTHERS THEN
    v_by := NULL;
  END;

  INSERT INTO public.training_goal_history (
    tech_id, training_focus, training_goal_start, training_goal_end, changed_by
  ) VALUES (
    OLD.id, OLD.training_focus, OLD.training_goal_start, OLD.training_goal_end, v_by
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_training_goals_keep_history ON public.technicians;
CREATE TRIGGER trg_training_goals_keep_history
  BEFORE UPDATE OF training_focus, training_goal_start, training_goal_end
  ON public.technicians
  FOR EACH ROW
  EXECUTE FUNCTION public.training_goals_keep_history();

-- Only admins can change Training Goals.
CREATE OR REPLACE FUNCTION public.app_save_training_focus(
  p_tech_id bigint,
  p_focus text DEFAULT NULL,
  p_goal_start text DEFAULT NULL,
  p_goal_end text DEFAULT NULL,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_focus text := nullif(trim(coalesce(p_focus, '')), '');
  v_start date;
  v_end date;
BEGIN
  IF NOT public.app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_tech_id IS NULL THEN
    RAISE EXCEPTION 'missing_tech';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.technicians t
    WHERE t.id = p_tech_id AND t.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  v_start := CASE
    WHEN p_goal_start IS NULL OR trim(p_goal_start) = '' THEN NULL
    ELSE p_goal_start::date
  END;
  v_end := CASE
    WHEN p_goal_end IS NULL OR trim(p_goal_end) = '' THEN NULL
    ELSE p_goal_end::date
  END;

  UPDATE public.technicians
     SET training_focus = v_focus,
         training_goal_start = v_start,
         training_goal_end = v_end
   WHERE id = p_tech_id
     AND deleted_at IS NULL;

  RETURN json_build_object(
    'ok', true,
    'training_focus', v_focus,
    'training_goal_start', v_start,
    'training_goal_end', v_end
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_training_goal_history(
  p_tech_id bigint,
  p_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_region text;
  v_role text;
  v_sess_region text;
  v_sess_tech bigint;
  v_rows json;
BEGIN
  SELECT t.region INTO v_region
  FROM public.technicians t
  WHERE t.id = p_tech_id AND t.deleted_at IS NULL;

  IF v_region IS NULL THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  IF NOT public.app_is_admin() THEN
    SELECT s.role, s.region, s.tech_id
      INTO v_role, v_sess_region, v_sess_tech
    FROM public.sessions s
    WHERE s.token = p_token
      AND s.expires_at > now();

    IF v_role IS NULL THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;

    IF v_role = 'technician' AND v_sess_tech IS DISTINCT FROM p_tech_id THEN
      RAISE EXCEPTION 'Not authorized';
    ELSIF v_role IS DISTINCT FROM 'technician'
      AND v_sess_region IS DISTINCT FROM 'ALL'
      AND v_sess_region IS DISTINCT FROM v_region THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
  END IF;

  SELECT coalesce(json_agg(row_to_json(x) ORDER BY x.changed_at DESC, x.id DESC), '[]'::json)
    INTO v_rows
  FROM (
    SELECT
      h.id,
      h.training_focus,
      h.training_goal_start,
      h.training_goal_end,
      h.changed_at,
      h.changed_by
    FROM public.training_goal_history h
    WHERE h.tech_id = p_tech_id
  ) x;

  RETURN v_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_training_focus(bigint, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_training_goal_history(bigint, text) TO anon, authenticated;
