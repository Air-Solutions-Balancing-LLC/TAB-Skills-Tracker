-- Verify NE assessment import — run in Supabase SQL Editor after ne-assessments-import.sql

-- 1) assessments table columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'assessments'
ORDER BY ordinal_position;

-- 2) FK column the app will use
SELECT public.app_assessments_fk_col() AS fk_column_used_by_app;

-- 3) NE technicians: do Excel names match DB rows?
WITH excel_names(name) AS (
  VALUES
    ('Alex Baichu'), ('Anatoliy Ilyuk'), ('Andrew Parziale'), ('Corey Crockett'),
    ('Dom Jean-Louis'), ('Don Beauchesne'), ('Dylan Conner'), ('Eric Olson'),
    ('Gary St. Clair'), ('James Dupass'), ('Jeremy Wickson'), ('Jimmy Anderson'),
    ('Jonny Cascarano'), ('Kody Collins'), ('Kurt Paradis'), ('Luisander Ruiz'),
    ('Matt O''Brien'), ('Richard Wilson'), ('Sean Sutherland'), ('Stavros Themeilis'),
    ('Thomas Ryan'), ('Tyler LeBlanc'), ('Vinny Fitzpatrick')
)
SELECT
  e.name AS excel_name,
  t.id,
  t.region,
  t.deleted_at IS NOT NULL AS deleted,
  (SELECT count(*) FROM assessments a
   WHERE a.technician_id = t.id) AS assessment_count
FROM excel_names e
LEFT JOIN technicians t
  ON lower(trim(t.name)) = lower(trim(e.name))
ORDER BY e.name;

-- 4) Unmatched Excel names (import would skip these)
WITH excel_names(name) AS (
  VALUES
    ('Alex Baichu'), ('Anatoliy Ilyuk'), ('Andrew Parziale'), ('Corey Crockett'),
    ('Dom Jean-Louis'), ('Don Beauchesne'), ('Dylan Conner'), ('Eric Olson'),
    ('Gary St. Clair'), ('James Dupass'), ('Jeremy Wickson'), ('Jimmy Anderson'),
    ('Jonny Cascarano'), ('Kody Collins'), ('Kurt Paradis'), ('Luisander Ruiz'),
    ('Matt O''Brien'), ('Richard Wilson'), ('Sean Sutherland'), ('Stavros Themeilis'),
    ('Thomas Ryan'), ('Tyler LeBlanc'), ('Vinny Fitzpatrick')
)
SELECT e.name AS unmatched_excel_name
FROM excel_names e
WHERE NOT EXISTS (
  SELECT 1 FROM technicians t
  WHERE lower(trim(t.name)) = lower(trim(e.name))
    AND t.deleted_at IS NULL
);
