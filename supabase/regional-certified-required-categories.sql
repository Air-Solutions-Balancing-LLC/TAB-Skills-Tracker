-- TAB Regional Technicians who are NEBB certified (CT or CP):
-- all required categories except Pre-Bootcamp.
-- Safe to re-run.

UPDATE public.technicians
   SET required_categories = '[
     "safety",
     "safety_instruments",
     "basic",
     "basic_solo_projects",
     "basic_survey_projects",
     "intermediate",
     "intermediate_7_12",
     "advanced",
     "special_testing_complex",
     "survey",
     "national_accounts"
   ]'::jsonb
 WHERE deleted_at IS NULL
   AND job_position = 'TAB Regional Technician'
   AND nebb_status IN ('NEBB CT', 'NEBB CP');
