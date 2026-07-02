-- National Accounts: one rated item using a projects-completed scale (1–5).
-- Safe to re-run.

INSERT INTO public.skills (skill_code, section_id, category, name, sort_order)
SELECT
  'na1',
  sec.id,
  'PROJECTS',
  'How many National Accounts projects have you completed?',
  1
FROM public.skill_sections sec
WHERE sec.skey = 'national_accounts'
ON CONFLICT (skill_code) DO UPDATE
  SET section_id = EXCLUDED.section_id,
      category   = EXCLUDED.category,
      name       = EXCLUDED.name,
      sort_order = EXCLUDED.sort_order,
      active     = true;

-- Deactivate any extra National Accounts skills if they were added by mistake.
UPDATE public.skills sk
SET active = false
FROM public.skill_sections sec
WHERE sk.section_id = sec.id
  AND sec.skey = 'national_accounts'
  AND sk.skill_code <> 'na1';
