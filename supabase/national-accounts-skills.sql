-- National Accounts: one row per job type; each rated 1–5 on projects completed.
-- Add/edit job types in Admin -> Manage Skills & Categories.
-- Safe to re-run.

-- Retire the single aggregate question.
UPDATE public.skills SET active = false WHERE skill_code = 'na1';

-- Remove duplicate seed rows if admin already added job types (sk### codes).
UPDATE public.skills SET active = false
WHERE skill_code IN ('na_tr', 'na_wg', 'na_on', 'na_tg');

-- Reactivate all other National Accounts job types.
UPDATE public.skills sk
SET active = true
FROM public.skill_sections sec
WHERE sk.section_id = sec.id
  AND sec.skey = 'national_accounts'
  AND sk.skill_code NOT IN ('na1', 'na_tr', 'na_wg', 'na_on', 'na_tg');

-- Seed example job types only when the section has no active skills yet.
INSERT INTO public.skills (skill_code, section_id, category, name, sort_order)
SELECT v.code, sec.id, v.cat, v.name, v.ord
FROM (VALUES
  ('na_tr', 'national_accounts', 'JOB TYPE', 'Texas Roadhouse', 1),
  ('na_wg', 'national_accounts', 'JOB TYPE', 'Walgreens', 2),
  ('na_on', 'national_accounts', 'JOB TYPE', 'Old Navy / Gap Jobs', 3),
  ('na_tg', 'national_accounts', 'JOB TYPE', 'Target', 4)
) AS v(code, skey, cat, name, ord)
JOIN public.skill_sections sec ON sec.skey = v.skey
WHERE NOT EXISTS (
  SELECT 1
  FROM public.skills existing
  WHERE existing.section_id = sec.id
    AND existing.active
    AND existing.skill_code <> 'na1'
)
ON CONFLICT (skill_code) DO UPDATE
  SET section_id = EXCLUDED.section_id,
      category   = EXCLUDED.category,
      name       = EXCLUDED.name,
      sort_order = EXCLUDED.sort_order,
      active     = true;
