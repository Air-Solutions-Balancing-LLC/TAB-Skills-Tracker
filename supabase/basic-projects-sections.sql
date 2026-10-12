-- TAB Basics Solo Projects + TAB Basics Survey Projects
-- Sit directly after Basic TAB Skills. Score = count of completed projects (0–4).
-- Safe to re-run.

-- Make room after Basic (sort_order 5): bump Intermediate and later by 2
UPDATE public.skill_sections
SET sort_order = sort_order + 2
WHERE sort_order >= 6
  AND skey NOT IN ('basic_solo_projects', 'basic_survey_projects');

INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode, active)
VALUES
  ('basic_solo_projects',   'TAB Basics Solo Projects',   '🏗️', '#0F6E56', NULL, 6, 'projects', NULL, true),
  ('basic_survey_projects', 'TAB Basics Survey Projects', '📐', '#1B3A6B', NULL, 7, 'projects', NULL, true)
ON CONFLICT (skey) DO UPDATE SET
  label = EXCLUDED.label,
  emoji = EXCLUDED.emoji,
  color = EXCLUDED.color,
  sort_order = EXCLUDED.sort_order,
  section_type = 'projects',
  avg_field = NULL,
  active = true;

-- Canonical order
UPDATE public.skill_sections SET sort_order = 1 WHERE skey = 'orientation';
UPDATE public.skill_sections SET sort_order = 2 WHERE skey = 'pre_bootcamp';
UPDATE public.skill_sections SET sort_order = 3 WHERE skey = 'safety';
UPDATE public.skill_sections SET sort_order = 4 WHERE skey = 'safety_instruments';
UPDATE public.skill_sections SET sort_order = 5 WHERE skey = 'basic';
UPDATE public.skill_sections SET sort_order = 6 WHERE skey = 'basic_solo_projects';
UPDATE public.skill_sections SET sort_order = 7 WHERE skey = 'basic_survey_projects';
UPDATE public.skill_sections SET sort_order = 8 WHERE skey = 'intermediate';
UPDATE public.skill_sections SET sort_order = 9 WHERE skey = 'advanced';
UPDATE public.skill_sections SET sort_order = 10 WHERE skey = 'survey';
UPDATE public.skill_sections SET sort_order = 11 WHERE skey = 'national_accounts';

-- Seed four projects in each category (codes are stable for raw_scores)
INSERT INTO public.skills (skill_code, section_id, category, name, sort_order)
SELECT v.code, sec.id, v.cat, v.name, v.ord
FROM (VALUES
  ('bsp1',  'basic_solo_projects',   'PROJECT', 'Project 1', 1),
  ('bsp2',  'basic_solo_projects',   'PROJECT', 'Project 2', 2),
  ('bsp3',  'basic_solo_projects',   'PROJECT', 'Project 3', 3),
  ('bsp4',  'basic_solo_projects',   'PROJECT', 'Project 4', 4),
  ('bsvp1', 'basic_survey_projects', 'PROJECT', 'Project 1', 1),
  ('bsvp2', 'basic_survey_projects', 'PROJECT', 'Project 2', 2),
  ('bsvp3', 'basic_survey_projects', 'PROJECT', 'Project 3', 3),
  ('bsvp4', 'basic_survey_projects', 'PROJECT', 'Project 4', 4)
) AS v(code, skey, cat, name, ord)
JOIN public.skill_sections sec ON sec.skey = v.skey
ON CONFLICT (skill_code) DO UPDATE SET
  section_id = EXCLUDED.section_id,
  category = EXCLUDED.category,
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  active = true;

-- Verify:
-- SELECT skey, label, sort_order, section_type FROM public.skill_sections WHERE active ORDER BY sort_order;
-- SELECT skill_code, name FROM public.skills WHERE skill_code LIKE 'bsp%' OR skill_code LIKE 'bsvp%' ORDER BY skill_code;
