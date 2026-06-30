-- Verify NE assessment import — run AFTER assessments-rpcs.sql + ne-assessments-import.sql

-- 1) Unmatched Excel names (import skips these)
WITH excel_names(name) AS (
  VALUES
    ('Alex Baichu'), ('Anatoliy Ilyuk'), ('Andrew Parziale'), ('Corey Crockett'),
    ('Dom Jean-Louis'), ('Don Beauchesne'), ('Dylan Conner'), ('Eric Olson'),
    ('Gary St. Clair'), ('James Dupass'), ('Jeremy Wickson'), ('Jimmy Anderson'),
    ('Jonny Cascarano'), ('Kody Collins'), ('Kurt Paradis'), ('Luisander Ruiz'),
    ('Matt O''Brien'), ('Richard Wilson'), ('Sean Sutherland'), ('Stavros Themeilis'),
    ('Thomas Ryan'), ('Tyler LeBlanc'), ('Vinny Fitzpatrick')
)
SELECT e.name AS unmatched_name
FROM excel_names e
WHERE app_match_technician_id(e.name) IS NULL;

-- 2) Latest assessment per NE tech (compare to Excel export)
SELECT
  t.name,
  t.region,
  max(a.date) AS latest_date,
  (SELECT a2.basic_avg FROM assessments a2
   WHERE a2.technician_id = t.id ORDER BY a2.date DESC LIMIT 1) AS latest_basic_avg,
  count(a.*) AS total_assessments
FROM technicians t
LEFT JOIN assessments a ON a.technician_id = t.id
WHERE t.region = 'NE' AND t.deleted_at IS NULL
GROUP BY t.id, t.name, t.region
ORDER BY t.name;

-- 3) Dom Jean-Louis detail — expect 2026-06-03 latest, basic_avg 3.0
SELECT a.date, a.safety_avg, a.basic_avg, a.intermediate_avg
FROM technicians t
JOIN assessments a ON a.technician_id = t.id
WHERE lower(trim(t.name)) = 'dom jean-louis'
ORDER BY a.date;
