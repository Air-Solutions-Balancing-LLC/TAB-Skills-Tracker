-- Quick check — run in Supabase SQL Editor after SW import

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'assessments'
  AND column_name IN ('technician_id', 'tech_id', 'date', 'basic_avg')
ORDER BY column_name;

SELECT 'luis_rosendo' AS check_name, t.name, a.date, a.basic_avg
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE lower(trim(t.name)) = 'luis rosendo'
ORDER BY a.date DESC;

SELECT 'june_2026_sw' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region = 'SW' AND t.deleted_at IS NULL AND a.date >= '2026-06-01';

SELECT t.name, max(a.date) AS latest_date, count(a.*) AS total
FROM public.technicians t
LEFT JOIN public.assessments a ON a.technician_id = t.id
WHERE t.region = 'SW' AND t.deleted_at IS NULL
GROUP BY t.id, t.name
ORDER BY t.name;
