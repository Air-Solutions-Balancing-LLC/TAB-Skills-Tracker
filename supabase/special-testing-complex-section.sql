-- Add "Special Testing / Complex Projects" after Advanced Skills.
-- Moves the specialty / commissioning / complex project skills into it.
-- Safe to re-run.

UPDATE public.skill_sections
SET sort_order = sort_order + 1
WHERE sort_order >= 11
  AND skey <> 'special_testing_complex';

INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode, active)
VALUES (
  'special_testing_complex',
  'Special Testing / Complex Projects',
  '🧪',
  '#6B5B95',
  NULL,
  11,
  'rated',
  NULL,
  true
)
ON CONFLICT (skey) DO UPDATE SET
  label = EXCLUDED.label,
  emoji = EXCLUDED.emoji,
  color = EXCLUDED.color,
  sort_order = EXCLUDED.sort_order,
  section_type = 'rated',
  avg_field = NULL,
  active = true;

-- Canonical order
UPDATE public.skill_sections SET sort_order = 10 WHERE skey = 'advanced';
UPDATE public.skill_sections SET sort_order = 11 WHERE skey = 'special_testing_complex';
UPDATE public.skill_sections SET sort_order = 12 WHERE skey = 'survey';
UPDATE public.skill_sections SET sort_order = 13 WHERE skey = 'national_accounts';

WITH dest AS (
  SELECT id AS section_id FROM public.skill_sections WHERE skey = 'special_testing_complex'
),
codes(code, ord) AS (
  VALUES
    ('a20', 1),
    ('a21', 2),
    ('a22', 3),
    ('a23', 4),
    ('a25', 5),
    ('a18', 6),
    ('sk264', 7),
    ('sk265', 8)
)
UPDATE public.skills sk
SET section_id = dest.section_id,
    sort_order = codes.ord,
    active = true
FROM dest, codes
WHERE sk.skill_code = codes.code;

-- Verify:
-- SELECT skey, label, sort_order FROM public.skill_sections WHERE active ORDER BY sort_order;
-- SELECT sk.skill_code, sk.category, sk.name, sk.sort_order
-- FROM public.skills sk
-- JOIN public.skill_sections s ON s.id = sk.section_id
-- WHERE s.skey = 'special_testing_complex' AND sk.active
-- ORDER BY sk.sort_order;
