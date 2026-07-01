-- Quick check — run in Supabase SQL Editor after RM + IM import

SELECT 'shane_reich' AS check_name, t.name, t.region, a.date, a.basic_avg
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE lower(trim(t.name)) = 'shane reich'
ORDER BY a.date DESC;

SELECT 'june_2026_rm_im' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region IN ('RM', 'IM') AND t.deleted_at IS NULL AND a.date >= '2026-06-01';

SELECT t.region, t.name, max(a.date) AS latest_date, count(a.*) AS total
FROM public.technicians t
LEFT JOIN public.assessments a ON a.technician_id = t.id
WHERE t.region IN ('RM', 'IM') AND t.deleted_at IS NULL
GROUP BY t.id, t.region, t.name
ORDER BY t.region, t.name;
