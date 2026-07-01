-- Mark every active technician 100% complete on Orientation + Pre-Bootcamp checklists.
-- Run once in Supabase -> SQL Editor (or: supabase db query --linked -f this file).
--
-- Orientation: checkbox items -> checklist_completed[skill_code] = true
-- Pre-Bootcamp: rated items -> rating 3 ("Multiple Times" = 100%)
-- Merges into existing checklist_completed without wiping other keys.
-- Safe to re-run (idempotent).

WITH orientation_complete AS (
  SELECT coalesce(
    jsonb_object_agg(sk.skill_code, 'true'::jsonb),
    '{}'::jsonb
  ) AS checks
  FROM public.skills sk
  JOIN public.skill_sections sec ON sec.id = sk.section_id
  WHERE sec.skey = 'orientation'
    AND sec.section_type = 'checklist'
    AND coalesce(sec.checklist_mode, 'checkbox') = 'checkbox'
    AND sec.active
    AND sk.active
),
pre_bootcamp_complete AS (
  SELECT coalesce(
    jsonb_object_agg(sk.skill_code, 3),
    '{}'::jsonb
  ) AS ratings
  FROM public.skills sk
  JOIN public.skill_sections sec ON sec.id = sk.section_id
  WHERE sec.skey = 'pre_bootcamp'
    AND sec.section_type = 'checklist'
    AND coalesce(sec.checklist_mode, 'checkbox') = 'rated'
    AND sec.active
    AND sk.active
),
checklist_complete AS (
  SELECT oc.checks || pbc.ratings AS merged
  FROM orientation_complete oc
  CROSS JOIN pre_bootcamp_complete pbc
)
UPDATE public.technicians t
SET checklist_completed = coalesce(t.checklist_completed, '{}'::jsonb) || cc.merged
FROM checklist_complete cc
WHERE t.deleted_at IS NULL;

-- Verify: skill counts per checklist section
SELECT sec.skey, count(*) AS skill_count
FROM public.skills sk
JOIN public.skill_sections sec ON sec.id = sk.section_id
WHERE sec.skey IN ('orientation', 'pre_bootcamp')
  AND sk.active
  AND sec.active
GROUP BY sec.skey
ORDER BY sec.skey;

-- Verify: sample technicians — orientation done + pre-bootcamp at rating 3
SELECT t.id, t.name, t.region,
  count(*) FILTER (
    WHERE sec.skey = 'orientation'
      AND (t.checklist_completed -> sk.skill_code)::boolean IS TRUE
  ) AS orientation_done,
  count(*) FILTER (WHERE sec.skey = 'orientation') AS orientation_total,
  count(*) FILTER (
    WHERE sec.skey = 'pre_bootcamp'
      AND (t.checklist_completed -> sk.skill_code)::int = 3
  ) AS pre_bootcamp_rated_3,
  count(*) FILTER (WHERE sec.skey = 'pre_bootcamp') AS pre_bootcamp_total
FROM public.technicians t
CROSS JOIN public.skills sk
JOIN public.skill_sections sec ON sec.id = sk.section_id
WHERE t.deleted_at IS NULL
  AND sec.skey IN ('orientation', 'pre_bootcamp')
  AND sk.active
  AND sec.active
GROUP BY t.id, t.name, t.region
ORDER BY t.name
LIMIT 20;
