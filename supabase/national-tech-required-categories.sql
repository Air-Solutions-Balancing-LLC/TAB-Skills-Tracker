-- TAB National Technicians: required categories + Training Focus + deadline.
-- Categories match Admin Edit Tech card:
--   Core Values + Math Skills, Safety and Instruments, Basic TAB Skills,
--   TAB Basics Solo Projects, Survey Solo Projects, Survey Accounts, National Accounts
-- Safe to re-run.

UPDATE public.technicians
   SET required_categories = '["safety","safety_instruments","basic","basic_solo_projects","basic_survey_projects","survey","national_accounts"]'::jsonb,
       training_focus = 'Be proficient in Surveys and have experience in all three types of Surveys',
       training_goal_end = '2027-02-02'::date
 WHERE deleted_at IS NULL
   AND job_position = 'TAB National Technician';
