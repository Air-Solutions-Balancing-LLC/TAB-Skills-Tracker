-- Set bootcamp_start_date = employment start_date + 45 days for active technicians.
-- Run in Supabase -> SQL Editor. Safe to re-run (overwrites bootcamp_start_date).

UPDATE public.technicians
SET bootcamp_start_date = start_date + interval '45 days'
WHERE deleted_at IS NULL
  AND start_date IS NOT NULL;

-- Verify sample
SELECT name, start_date, bootcamp_start_date
FROM public.technicians
WHERE deleted_at IS NULL
  AND start_date IS NOT NULL
ORDER BY name
LIMIT 10;

-- Technicians still missing bootcamp date (no employment start date)
SELECT id, name, region
FROM public.technicians
WHERE deleted_at IS NULL
  AND start_date IS NULL
ORDER BY name;
