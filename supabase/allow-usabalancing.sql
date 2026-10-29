-- Allow the old USA Balancing Microsoft accounts, and save Alfredo's address.
-- Run once in Supabase → SQL Editor.

CREATE OR REPLACE FUNCTION public.app_allowed_email(p_email text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT lower(split_part(trim(p_email), '@', 2)) IN (
    'airadigmsolutions.com',
    'kitchenenergysolutions.com',
    'usabalancing.com'
  );
$$;

UPDATE public.technicians
   SET email = 'alfredo.salas@usabalancing.com'
 WHERE id = 50
   AND lower(trim(name)) = 'alfredo salas';
