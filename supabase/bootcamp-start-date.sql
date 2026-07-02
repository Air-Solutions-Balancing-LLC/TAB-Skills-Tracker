-- Add editable bootcamp start date for technicians.
-- Run in Supabase -> SQL Editor. Safe to re-run.

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS bootcamp_start_date date;
