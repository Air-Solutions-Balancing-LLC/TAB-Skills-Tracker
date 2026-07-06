-- Convert TAB Survey Skills into Survey Accounts (job-type list, 1–5 times completed).
-- Clears legacy survey scores. Add survey jobs via Admin -> Manage Skills & Categories.
-- Safe to re-run.

UPDATE public.skill_sections
SET label = 'Survey Accounts',
    emoji = '🟪',
    color = '#AFA9EC',
    section_type = 'rated'
WHERE skey = 'survey';

-- Retire legacy per-skill survey items (sv1, sv2, …).
UPDATE public.skills sk
SET active = false
FROM public.skill_sections sec
WHERE sk.section_id = sec.id
  AND sec.skey = 'survey';

-- Clear stored survey section averages.
UPDATE public.assessments
SET survey_avg = NULL
WHERE survey_avg IS NOT NULL;

-- Remove legacy survey skill codes from raw_scores snapshots.
WITH survey_codes AS (
  SELECT sk.skill_code
  FROM public.skills sk
  JOIN public.skill_sections sec ON sec.id = sk.section_id
  WHERE sec.skey = 'survey'
    AND sk.skill_code LIKE 'sv%'
)
UPDATE public.assessments a
SET raw_scores = COALESCE((
  SELECT jsonb_object_agg(e.key, e.value)
  FROM jsonb_each(COALESCE(a.raw_scores::jsonb, '{}'::jsonb)) AS e(key, value)
  WHERE e.key NOT IN (SELECT skill_code FROM survey_codes)
), '{}'::jsonb)::json
WHERE a.raw_scores IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM jsonb_each(COALESCE(a.raw_scores::jsonb, '{}'::jsonb)) AS e(key, value)
    WHERE e.key IN (SELECT skill_code FROM survey_codes)
  );
