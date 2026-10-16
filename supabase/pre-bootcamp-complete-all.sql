-- Mark every active technician 100% complete on Pre-Bootcamp checklist.
-- Run once in Supabase -> SQL Editor (or: supabase db query --linked -f this file).
--
-- Pre-Bootcamp: rated items -> rating 3 ("Can Perform Independently" = 100%)
-- Merges into existing checklist_completed without wiping other keys.
-- Safe to re-run (idempotent).
-- Orientation tracking was removed and is intentionally not updated here.

WITH pre_bootcamp_complete AS (
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
)
UPDATE public.technicians t
SET checklist_completed = coalesce(t.checklist_completed, '{}'::jsonb) || pbc.ratings
FROM pre_bootcamp_complete pbc
WHERE t.deleted_at IS NULL;

-- Verify: skill counts for Pre-Bootcamp
SELECT sec.skey, count(*) AS skill_count
FROM public.skills sk
JOIN public.skill_sections sec ON sec.id = sk.section_id
WHERE sec.skey = 'pre_bootcamp'
  AND sk.active
  AND sec.active
GROUP BY sec.skey
ORDER BY sec.skey;

-- Verify: sample technicians — pre-bootcamp at rating 3
SELECT t.id, t.name, t.region,
  count(*) FILTER (
    WHERE sec.skey = 'pre_bootcamp'
      AND (t.checklist_completed -> sk.skill_code)::int = 3
  ) AS pre_bootcamp_rated_3,
  count(*) FILTER (WHERE sec.skey = 'pre_bootcamp') AS pre_bootcamp_total
FROM public.technicians t
CROSS JOIN public.skills sk
JOIN public.skill_sections sec ON sec.id = sk.section_id
WHERE t.deleted_at IS NULL
  AND sec.skey = 'pre_bootcamp'
  AND sk.active
  AND sec.active
GROUP BY t.id, t.name, t.region
ORDER BY t.name
LIMIT 20;
