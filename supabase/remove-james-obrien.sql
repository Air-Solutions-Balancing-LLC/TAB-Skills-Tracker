-- Soft-delete James O'Brien so he no longer appears on dashboards/reports.
-- Assessment history is preserved. Safe to re-run.

UPDATE public.technicians
SET
  deleted_at = coalesce(deleted_at, now()),
  prev_region = coalesce(prev_region, region),
  region = NULL
WHERE deleted_at IS NULL
  AND (
    lower(name) = lower('James O''Brien')
    OR lower(name) = lower('James Obrien')
    OR lower(name) LIKE 'james o%brien%'
  );

SELECT id, name, region, prev_region, deleted_at
FROM public.technicians
WHERE lower(name) LIKE 'james o%brien%'
   OR lower(name) LIKE 'james obrien%';
