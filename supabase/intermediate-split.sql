-- Split Intermediate into:
--   intermediate          → Intermediate Skills (4 to 6 Months)
--   intermediate_7_12     → Intermediate Skills (7 to 12 Months)
-- Safe to re-run.

-- Make room after current Intermediate (sort_order 8)
UPDATE public.skill_sections
SET sort_order = sort_order + 1
WHERE sort_order >= 9
  AND skey <> 'intermediate_7_12';

UPDATE public.skill_sections
SET label = 'Intermediate Skills (4 to 6 Months)',
    section_type = 'rated',
    sort_order = 8
WHERE skey = 'intermediate';

INSERT INTO public.skill_sections (skey, label, emoji, color, avg_field, sort_order, section_type, checklist_mode, active)
VALUES (
  'intermediate_7_12',
  'Intermediate Skills (7 to 12 Months)',
  '🔷',
  '#5B8FD9',
  NULL,
  9,
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
UPDATE public.skill_sections SET sort_order = 1 WHERE skey = 'orientation';
UPDATE public.skill_sections SET sort_order = 2 WHERE skey = 'pre_bootcamp';
UPDATE public.skill_sections SET sort_order = 3 WHERE skey = 'safety';
UPDATE public.skill_sections SET sort_order = 4 WHERE skey = 'safety_instruments';
UPDATE public.skill_sections SET sort_order = 5 WHERE skey = 'basic';
UPDATE public.skill_sections SET sort_order = 6 WHERE skey = 'basic_solo_projects';
UPDATE public.skill_sections SET sort_order = 7 WHERE skey = 'basic_survey_projects';
UPDATE public.skill_sections SET sort_order = 8 WHERE skey = 'intermediate';
UPDATE public.skill_sections SET sort_order = 9 WHERE skey = 'intermediate_7_12';
UPDATE public.skill_sections SET sort_order = 10 WHERE skey = 'advanced';
UPDATE public.skill_sections SET sort_order = 11 WHERE skey = 'survey';
UPDATE public.skill_sections SET sort_order = 12 WHERE skey = 'national_accounts';

-- 4–6 months skills (from Manage Skills screenshot)
WITH solo AS (
  SELECT id AS section_id FROM public.skill_sections WHERE skey = 'intermediate'
),
codes(code, ord) AS (
  VALUES
    ('i4',1),('i6',2),('i15',3),('i14',4),('i16',5),('i18',6),
    ('i17',7),('i26',8),('i8',9),('i23',10),('i24',11),('i25',12)
)
UPDATE public.skills sk
SET section_id = solo.section_id,
    sort_order = codes.ord,
    active = true
FROM solo, codes
WHERE sk.skill_code = codes.code;

-- Remaining intermediate skills → 7 to 12 months
WITH late AS (
  SELECT id AS section_id FROM public.skill_sections WHERE skey = 'intermediate_7_12'
),
codes(code, ord) AS (
  VALUES
    ('i10',1),('i11',2),('i12',3),('i19',4),('i20',5),('i21',6),('i22',7),
    ('i34',8),('i35',9),('i27',10),('i28',11),('i29',12),('i30',13),
    ('i31',14),('i32',15),('i33',16),('i36',17),('i37',18),('i38',19),
    ('i39',20),('i44',21)
)
UPDATE public.skills sk
SET section_id = late.section_id,
    sort_order = codes.ord,
    active = true
FROM late, codes
WHERE sk.skill_code = codes.code;

-- Any other active skills still on intermediate that are not in the 4–6 list
-- move to 7–12 (keeps stray/admin-added items with the later band).
UPDATE public.skills sk
SET section_id = late.id,
    sort_order = sk.sort_order + 100
FROM public.skill_sections mid, public.skill_sections late
WHERE mid.skey = 'intermediate'
  AND late.skey = 'intermediate_7_12'
  AND sk.section_id = mid.id
  AND sk.active
  AND sk.skill_code NOT IN (
    'i4','i6','i15','i14','i16','i18','i17','i26','i8','i23','i24','i25'
  );

-- Re-number 7–12 cleanly
WITH ordered AS (
  SELECT sk.id, row_number() OVER (ORDER BY sk.sort_order, sk.id) AS rn
  FROM public.skills sk
  JOIN public.skill_sections s ON s.id = sk.section_id
  WHERE s.skey = 'intermediate_7_12' AND sk.active
)
UPDATE public.skills sk
SET sort_order = ordered.rn
FROM ordered
WHERE sk.id = ordered.id;

-- Verify:
-- SELECT skey, label, sort_order FROM public.skill_sections WHERE active ORDER BY sort_order;
-- SELECT s.skey, sk.skill_code, sk.name, sk.sort_order
-- FROM public.skills sk JOIN public.skill_sections s ON s.id = sk.section_id
-- WHERE s.skey IN ('intermediate','intermediate_7_12') AND sk.active
-- ORDER BY s.sort_order, sk.sort_order;
