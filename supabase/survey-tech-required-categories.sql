-- TAB Survey Technicians: required categories for Overall Proficiency.
-- Matches Admin Edit Tech card:
--   Core Values + Math Skills, Safety and Instruments, Basic TAB Skills,
--   Survey Solo Projects, Survey Accounts
-- Safe to re-run.

UPDATE public.technicians
   SET required_categories = '["safety","safety_instruments","basic","basic_survey_projects","survey"]'::jsonb
 WHERE deleted_at IS NULL
   AND job_position = 'TAB Survey Technician';
