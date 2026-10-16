-- Remove Orientation tracking from TAB Skills Tracker.
-- Deactivates the section + skills and strips 'orientation' from required_categories.
-- Safe to re-run. Pre-Bootcamp is unchanged.

UPDATE public.skills
   SET active = false
 WHERE section_id IN (
   SELECT id FROM public.skill_sections WHERE skey = 'orientation'
 );

UPDATE public.skill_sections
   SET active = false
 WHERE skey = 'orientation';

UPDATE public.technicians t
   SET required_categories = sub.cleaned
  FROM (
    SELECT tech.id,
           coalesce((
             SELECT jsonb_agg(to_jsonb(x) ORDER BY ord)
             FROM jsonb_array_elements_text(coalesce(tech.required_categories, '[]'::jsonb))
                  WITH ORDINALITY AS e(x, ord)
             WHERE e.x <> 'orientation'
           ), '[]'::jsonb) AS cleaned
      FROM public.technicians tech
     WHERE tech.required_categories IS NOT NULL
       AND jsonb_typeof(tech.required_categories) = 'array'
       AND EXISTS (
         SELECT 1
           FROM jsonb_array_elements_text(tech.required_categories) e(x)
          WHERE e.x = 'orientation'
       )
  ) sub
 WHERE t.id = sub.id;

-- Hide Orientation from Admin Manage Skills board too.
CREATE OR REPLACE FUNCTION public.app_admin_list_skills()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT app_is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'id', s.id, 'key', s.skey, 'section', s.label, 'emoji', s.emoji, 'color', s.color,
             'section_type', s.section_type,
             'checklist_mode', s.checklist_mode,
             'locked', (s.avg_field IS NOT NULL),
             'skills', COALESCE((
               SELECT jsonb_agg(jsonb_build_object('id', sk.id, 'code', sk.skill_code, 'cat', sk.category, 'name', sk.name)
                                ORDER BY sk.sort_order, sk.id)
               FROM public.skills sk
               WHERE sk.section_id = s.id
             ), '[]'::jsonb)
           )
           ORDER BY s.sort_order, s.id
         ), '[]'::jsonb) INTO v_result
  FROM public.skill_sections s
  WHERE s.skey IS DISTINCT FROM 'orientation';

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_skills() TO authenticated;
