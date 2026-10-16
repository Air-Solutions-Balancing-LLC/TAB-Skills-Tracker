-- TAB Survey Technicians: set Training Focus + deadline.
-- Safe to re-run.

UPDATE public.technicians
   SET training_focus = 'Capable of performing the 3 levels of Surveys on their own, with near perfect Survey Reports',
       training_goal_end = '2026-12-15'::date
 WHERE deleted_at IS NULL
   AND job_position = 'TAB Survey Technician';
