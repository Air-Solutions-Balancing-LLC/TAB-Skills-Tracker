-- National Accounts scored section (6th section average).
-- Run in Supabase -> SQL Editor after assessments-rpcs.sql. Safe to re-run.
--
-- Section appears for all technicians. Add skills via Admin -> Manage Skills & Categories.

ALTER TABLE public.assessments
  ADD COLUMN IF NOT EXISTS national_accounts_avg numeric;

INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode)
VALUES (
  'national_accounts',
  'National Accounts',
  '🏢',
  '#5B7C99',
  'national_accounts_avg',
  8,
  'rated',
  NULL
)
ON CONFLICT (skey) DO UPDATE
  SET label = EXCLUDED.label,
      emoji = EXCLUDED.emoji,
      color = EXCLUDED.color,
      avg_field = EXCLUDED.avg_field,
      sort_order = EXCLUDED.sort_order,
      section_type = 'rated';
