-- Add scored category "Safety and Instruments" above Basic TAB Skills.
-- Safe to re-run.

-- Make room: bump Basic and everything after it up by 1
UPDATE public.skill_sections
SET sort_order = sort_order + 1
WHERE sort_order >= 4
  AND skey <> 'safety_instruments';

INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode, active)
VALUES ('safety_instruments', 'Safety and Instruments', '🧰', '#0F6E56', NULL, 4, 'rated', NULL, true)
ON CONFLICT (skey) DO UPDATE SET
  label = EXCLUDED.label,
  emoji = EXCLUDED.emoji,
  color = EXCLUDED.color,
  sort_order = EXCLUDED.sort_order,
  section_type = 'rated',
  active = true;

-- Canonical order after insert
UPDATE public.skill_sections SET sort_order = 1 WHERE skey = 'orientation';
UPDATE public.skill_sections SET sort_order = 2 WHERE skey = 'pre_bootcamp';
UPDATE public.skill_sections SET sort_order = 3 WHERE skey = 'safety';
UPDATE public.skill_sections SET sort_order = 4 WHERE skey = 'safety_instruments';
UPDATE public.skill_sections SET sort_order = 5 WHERE skey = 'basic';
UPDATE public.skill_sections SET sort_order = 6 WHERE skey = 'intermediate';
UPDATE public.skill_sections SET sort_order = 7 WHERE skey = 'advanced';
UPDATE public.skill_sections SET sort_order = 8 WHERE skey = 'survey';
UPDATE public.skill_sections SET sort_order = 9 WHERE skey = 'national_accounts';

-- Verify:
-- SELECT skey, label, sort_order FROM public.skill_sections WHERE active ORDER BY sort_order;
