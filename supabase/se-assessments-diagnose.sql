-- Quick check — run in Supabase SQL Editor after SE import

SELECT 'brian_randolph' AS check_name, t.name, a.date, a.basic_avg
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE lower(trim(t.name)) = 'brian randolph'
ORDER BY a.date DESC;

SELECT 'june_2026_se' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region = 'SE' AND t.deleted_at IS NULL AND a.date >= '2026-06-01';

SELECT t.name, max(a.date) AS latest_date, count(a.*) AS total
FROM public.technicians t
LEFT JOIN public.assessments a ON a.technician_id = t.id
WHERE t.region = 'SE' AND t.deleted_at IS NULL
GROUP BY t.id, t.name
ORDER BY t.name;
