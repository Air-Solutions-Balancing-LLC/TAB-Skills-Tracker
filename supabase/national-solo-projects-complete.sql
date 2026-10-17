-- National region: mark TAB Basics Solo Projects complete with job name "see USAB"
-- for all active National technicians except:
--   Javed Mohammend, Rafael Torres
-- Does NOT include National-TAB Survey.
--
-- Merges into each tech's latest assessment raw_scores (creates one if none).
-- Safe to re-run (idempotent).
-- Run in Supabase → SQL Editor (or: supabase db query --linked -f this file).

DO $$
DECLARE
  v_fk text;
  v_patch jsonb;
  v_updated int := 0;
  v_inserted int := 0;
BEGIN
  SELECT column_name
  INTO v_fk
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'assessments'
    AND column_name IN ('technician_id', 'tech_id')
  ORDER BY CASE column_name WHEN 'technician_id' THEN 1 ELSE 2 END
  LIMIT 1;

  IF v_fk IS NULL THEN
    RAISE EXCEPTION 'assessments table has no technician_id / tech_id column';
  END IF;

  SELECT coalesce(jsonb_object_agg(x.k, x.v), '{}'::jsonb)
  INTO v_patch
  FROM (
    SELECT sk.skill_code AS k, to_jsonb(1) AS v
    FROM public.skills sk
    JOIN public.skill_sections sec ON sec.id = sk.section_id
    WHERE sec.skey = 'basic_solo_projects'
      AND sec.section_type = 'projects'
      AND sec.active
      AND sk.active
    UNION ALL
    SELECT sk.skill_code || '__job', to_jsonb('see USAB'::text)
    FROM public.skills sk
    JOIN public.skill_sections sec ON sec.id = sk.section_id
    WHERE sec.skey = 'basic_solo_projects'
      AND sec.section_type = 'projects'
      AND sec.active
      AND sk.active
  ) x;

  IF v_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'No basic_solo_projects skills found — check Manage Category / skills.sql';
  END IF;

  EXECUTE format($q$
    WITH targets AS (
      SELECT t.id
      FROM public.technicians t
      WHERE t.region = 'National'
        AND t.deleted_at IS NULL
        AND lower(trim(t.name)) NOT IN (
          'javed mohammend',
          'javed mohammed',
          'rafael torres'
        )
    ),
    latest AS (
      SELECT DISTINCT ON (a.%1$I) a.id AS assessment_id, a.%1$I AS tech_id
      FROM public.assessments a
      JOIN targets t ON t.id = a.%1$I
      ORDER BY a.%1$I, a.date DESC, a.id DESC
    )
    UPDATE public.assessments a
    SET raw_scores = coalesce(a.raw_scores::jsonb, '{}'::jsonb) || $1::jsonb
    FROM latest l
    WHERE a.id = l.assessment_id
  $q$, v_fk)
  USING v_patch;
  GET DIAGNOSTICS v_updated = ROW_COUNT;

  EXECUTE format($q$
    WITH targets AS (
      SELECT t.id, t.name
      FROM public.technicians t
      WHERE t.region = 'National'
        AND t.deleted_at IS NULL
        AND lower(trim(t.name)) NOT IN (
          'javed mohammend',
          'javed mohammed',
          'rafael torres'
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.assessments a WHERE a.%1$I = t.id
        )
    )
    INSERT INTO public.assessments (%1$I, date, comment, raw_scores)
    SELECT t.id, CURRENT_DATE,
           'National Solo Projects backfill — job name see USAB',
           $1::jsonb
    FROM targets t
  $q$, v_fk)
  USING v_patch;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RAISE NOTICE 'National Solo Projects: updated % latest assessment(s), inserted % new assessment(s)',
    v_updated, v_inserted;
END $$;

-- Verify: National techs (not National-TAB Survey)
WITH solo AS (
  SELECT sk.skill_code
  FROM public.skills sk
  JOIN public.skill_sections sec ON sec.id = sk.section_id
  WHERE sec.skey = 'basic_solo_projects' AND sk.active AND sec.active
),
latest AS (
  SELECT DISTINCT ON (a.technician_id) a.technician_id AS tech_id, a.date, a.raw_scores::jsonb AS raw
  FROM public.assessments a
  JOIN public.technicians t ON t.id = a.technician_id
  WHERE t.region = 'National' AND t.deleted_at IS NULL
  ORDER BY a.technician_id, a.date DESC, a.id DESC
)
SELECT
  t.name,
  CASE
    WHEN lower(trim(t.name)) IN ('javed mohammend','javed mohammed','rafael torres')
    THEN 'EXCLUDED'
    ELSE 'INCLUDED'
  END AS status,
  l.date AS latest_assessment,
  (SELECT count(*) FROM solo s
   WHERE (l.raw ->> s.skill_code) IN ('1','true')
     AND trim(coalesce(l.raw ->> (s.skill_code || '__job'), '')) = 'see USAB'
  ) AS solo_complete_see_usab,
  (SELECT count(*) FROM solo) AS solo_total
FROM public.technicians t
LEFT JOIN latest l ON l.tech_id = t.id
WHERE t.region = 'National' AND t.deleted_at IS NULL
ORDER BY status DESC, t.name;
