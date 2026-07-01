-- Quick check — run in Supabase SQL Editor

-- 1) Assessment table columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'assessments'
  AND column_name IN ('technician_id', 'tech_id', 'date', 'basic_avg')
ORDER BY column_name;

-- 2) Dom Jean-Louis rows
SELECT 'dom_rows' AS check_name, t.id AS tech_id, t.name, t.region,
       a.date, a.technician_id, a.safety_avg, a.basic_avg
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE lower(trim(t.name)) = 'dom jean-louis'
ORDER BY a.date DESC;

-- 3) June 2026 NE count (expect >= 5 after patch)
SELECT 'june_2026_ne' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region = 'NE' AND t.deleted_at IS NULL AND a.date >= '2026-06-01';

-- 4) Latest date per NE tech
SELECT t.name, max(a.date) AS latest_date, count(a.*) AS total
FROM public.technicians t
LEFT JOIN public.assessments a ON a.technician_id = t.id
WHERE t.region = 'NE' AND t.deleted_at IS NULL
GROUP BY t.id, t.name
ORDER BY t.name;
