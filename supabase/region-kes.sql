-- Rename the "Survey" region to "KES".
-- The region is stored on technician records (current region and the saved
-- prev_region used by soft-delete). Run this once in the Supabase SQL editor
-- so existing "Survey" technicians stay visible under the new "KES" region.

update public.technicians
   set region = 'KES'
 where region = 'Survey';

update public.technicians
   set prev_region = 'KES'
 where prev_region = 'Survey';
