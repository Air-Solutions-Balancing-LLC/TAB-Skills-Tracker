-- Seed CT Path cohort / exam scheduled / notes from the Path to NEBB CT spreadsheet.
-- Does NOT overwrite employee start_date (milestones always calculate from the app start date:
-- Training +2.0 yrs, Exam +2.5 yrs, Anniv +3.0 yrs).
-- Safe to re-run. Matches technicians by lower(trim(name)).
-- Run after supabase/ct-path.sql.

CREATE TEMP TABLE IF NOT EXISTS _ct_path_sheet (
  name text,
  start_date date,
  cohort text,
  exam_scheduled date,
  notes text
);
TRUNCATE _ct_path_sheet;

INSERT INTO _ct_path_sheet (name, start_date, cohort, exam_scheduled, notes) VALUES
  ('Anatoliy Ilyuk', date '2013-05-20', 'Feb-Apr 2024', NULL,
   $n$Anatoliy and I worked together 1-on-1 to prep for his exam and he passed it on Apr 12, 2024. But he didn't follow up with recertification and was decertified mid 2025 (I think).$n$),
  ('Frederic Bahati', date '2024-06-24', 'Jan-Apr 2026', date '2026-12-12',
   $n$Freddie's exam wasn't scheduled early enough for Apr 2026. He joined the Jun-Sept 2026 Cohort. Failed exam on Sept 12, 2026. Rescheduled for Dec 12, 2026.$n$),
  ('Stranten Seui-Purdy', date '2024-07-29', NULL, NULL,
   $n$Paused on CT requirement due to uncertainty of moving schedule.$n$),
  ('Victor Berrios', date '2024-10-14', NULL, NULL,
   $n$Transitioned from Regional SW to Trainer for Nat'l Survey. Reconsider CT plan.$n$),
  ('Chris Conejo', date '2025-01-06', 'Jun-Sept 2026', NULL,
   $n$Chris didn't keep up with the Jun-Sept cohort. He'll join the next one.$n$),
  ('Joe Figone', date '2025-04-28', NULL, NULL, NULL),
  ('Austin Winters', date '2025-05-27', NULL, NULL, NULL),
  ('Tyler LeBlanc', date '2025-06-05', 'Jun-Sept 2026', NULL,
   $n$Tyler's exam wasn't scheduled early enough for Sept 2026. Still waiting to hear exam date.$n$),
  ('Brian Randolph', date '2025-06-23', NULL, NULL, NULL),
  ('Cameron Smith', date '2025-06-23', NULL, NULL, NULL),
  ('Jonny Cascarano', date '2025-07-14', NULL, NULL, NULL),
  ('Grant Gugel', date '2025-08-05', NULL, NULL, NULL),
  ('Nicholas Gray', date '2025-08-05', NULL, NULL, NULL),
  ('Alex Barajas', date '2025-09-02', NULL, NULL, NULL),
  ('DeAndre Black', date '2025-09-02', NULL, NULL, NULL),
  ('Keith Parker', date '2025-09-02', NULL, NULL, NULL),
  ('Paul Samuelson', date '2025-09-02', NULL, NULL, NULL),
  ('Richard Wilson', date '2025-09-02', NULL, NULL, NULL),
  ('Sean Sutherland', date '2025-10-07', NULL, NULL, NULL),
  ('Henry Boyle', date '2025-11-04', NULL, NULL, NULL),
  ('Jonathan Gonzalez', date '2025-11-04', NULL, NULL, NULL);

UPDATE public.technicians t
SET
  ct_training_cohort = COALESCE(s.cohort, t.ct_training_cohort),
  ct_exam_scheduled = COALESCE(s.exam_scheduled, t.ct_exam_scheduled),
  ct_path_notes = COALESCE(s.notes, t.ct_path_notes)
FROM _ct_path_sheet s
WHERE lower(trim(t.name)) = lower(trim(s.name))
  AND t.deleted_at IS NULL
  AND (s.cohort IS NOT NULL OR s.exam_scheduled IS NOT NULL OR s.notes IS NOT NULL);

-- Who matched / who is still missing from the seed.
SELECT s.name AS sheet_name,
       t.id AS tech_id,
       t.start_date AS app_start_date,
       s.start_date AS sheet_start_date,
       t.ct_training_cohort,
       t.ct_exam_scheduled,
       left(coalesce(t.ct_path_notes,''), 80) AS notes_preview
FROM _ct_path_sheet s
LEFT JOIN public.technicians t
  ON lower(trim(t.name)) = lower(trim(s.name))
 AND t.deleted_at IS NULL
ORDER BY s.start_date, s.name;
