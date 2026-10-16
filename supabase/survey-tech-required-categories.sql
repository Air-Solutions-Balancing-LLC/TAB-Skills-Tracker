-- TAB Survey Technicians: only Core Values, Safety & Instruments, Basic TAB Skills,
-- and Survey Solo Projects are required for Overall Proficiency.
-- Safe to re-run.

UPDATE public.technicians
   SET required_categories = '["safety","safety_instruments","basic","basic_survey_projects"]'::jsonb
 WHERE deleted_at IS NULL
   AND job_position = 'TAB Survey Technician';
