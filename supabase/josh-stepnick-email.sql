-- Josh Stepnick signs in with his USA Balancing Microsoft account.
-- The tracker still has the Airadigm address, so sign-in does not match him.
-- Run once in Supabase → SQL Editor.

UPDATE public.technicians
   SET email = 'josh.stepnick@usabalancing.com'
 WHERE id = 58
   AND lower(trim(name)) = 'josh stepnick'
   AND deleted_at IS NULL
   AND NOT EXISTS (
     SELECT 1
     FROM public.technicians other
     WHERE other.id <> 58
       AND lower(trim(other.email)) = 'josh.stepnick@usabalancing.com'
   );

UPDATE public.app_people
   SET email = 'josh.stepnick@usabalancing.com',
       full_name = COALESCE(NULLIF(trim(full_name), ''), 'Josh Stepnick'),
       role = 'technician',
       tech_id = COALESCE(tech_id, 58)
 WHERE tech_id = 58
    OR lower(trim(email)) = 'josh.stepnick@airadigmsolutions.com';

INSERT INTO public.app_people (email, role, full_name, region, tech_id)
SELECT 'josh.stepnick@usabalancing.com', 'technician', 'Josh Stepnick', 'National', 58
WHERE NOT EXISTS (
  SELECT 1
  FROM public.app_people
  WHERE tech_id = 58
     OR lower(trim(email)) = 'josh.stepnick@usabalancing.com'
);

SELECT t.id, t.name, t.region, t.email AS tech_email, p.email AS person_email, p.role
FROM public.technicians t
LEFT JOIN public.app_people p ON p.tech_id = t.id
WHERE t.id = 58;
