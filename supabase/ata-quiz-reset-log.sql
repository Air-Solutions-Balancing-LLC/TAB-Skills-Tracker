-- Completed rows from the Quiz Reset Log (ATA progress since Feb 2025.xlsx).
-- Saves the history only. Does not email or message anyone about a call.
-- TAB-B-400 is the Basics final in Teachable, stored here as TAB-B-401.
-- Safe to re-run: a row already saved for that technician, lesson, and day is skipped.
-- Pending requests are not included.

CREATE TEMP TABLE quiz_reset_log_src (
  tech_name text,
  lesson_code text,
  reset_on date,
  external_id text
);
INSERT INTO quiz_reset_log_src (tech_name, lesson_code, reset_on, external_id) VALUES
  ('Andrew Lacobee', 'TAB-B-109', '2026-07-22', 'quiz-reset-log:andrew-lacobee:TAB-B-109:2026-07-22'),
  ('Luis Rosendo', 'TAB-B-207', '2026-07-23', 'quiz-reset-log:luis-rosendo:TAB-B-207:2026-07-23'),
  ('Luis Rosendo', 'TAB-B-208', '2026-07-23', 'quiz-reset-log:luis-rosendo:TAB-B-208:2026-07-23'),
  ('Richard Wilson', 'TAB-A-201', '2026-07-23', 'quiz-reset-log:richard-wilson:TAB-A-201:2026-07-23'),
  ('Chad Lorenz', 'TAB-B-205', '2026-07-23', 'quiz-reset-log:chad-lorenz:TAB-B-205:2026-07-23'),
  ('Richard Wilson', 'TAB-A-202', '2026-07-29', 'quiz-reset-log:richard-wilson:TAB-A-202:2026-07-29'),
  ('Dom Jean-Louis', 'TAB-I-103', '2026-07-29', 'quiz-reset-log:dom-jean-louis:TAB-I-103:2026-07-29'),
  ('Clinton Duru', 'TAB-B-101', '2026-07-30', 'quiz-reset-log:clinton-duru:TAB-B-101:2026-07-30'),
  ('Sean Sutherland', 'TAB-A-203', '2026-07-31', 'quiz-reset-log:sean-sutherland:TAB-A-203:2026-07-31'),
  ('Richard Wilson', 'TAB-A-203', '2026-08-06', 'quiz-reset-log:richard-wilson:TAB-A-203:2026-08-06'),
  ('Angel Lopez', 'TAB-B-301', '2026-08-18', 'quiz-reset-log:angel-lopez:TAB-B-301:2026-08-18'),
  ('Angel Lopez', 'TAB-B-110', '2026-08-18', 'quiz-reset-log:angel-lopez:TAB-B-110:2026-08-18'),
  ('Javed Esa Mohammed', 'TAB-B-101', '2026-08-19', 'quiz-reset-log:javed-esa-mohammed:TAB-B-101:2026-08-19'),
  ('David Summiel', 'TAB-B-101', '2026-08-20', 'quiz-reset-log:david-summiel:TAB-B-101:2026-08-20'),
  ('Bilardo Artiga', 'TAB-B-101', '2026-08-21', 'quiz-reset-log:bilardo-artiga:TAB-B-101:2026-08-21'),
  ('Angel Lopez', 'TAB-B-302', '2026-08-24', 'quiz-reset-log:angel-lopez:TAB-B-302:2026-08-24'),
  ('James Bell', 'TAB-B-106', '2026-08-27', 'quiz-reset-log:james-bell:TAB-B-106:2026-08-27'),
  ('Richard Wilson', 'TAB-A-302', '2026-08-28', 'quiz-reset-log:richard-wilson:TAB-A-302:2026-08-28'),
  ('David Summiel', 'TAB-B-105', '2026-08-28', 'quiz-reset-log:david-summiel:TAB-B-105:2026-08-28'),
  ('Clinton Duru', 'TAB-B-105', '2026-08-31', 'quiz-reset-log:clinton-duru:TAB-B-105:2026-08-31'),
  ('Derrick Jackson', 'TAB-B-102', '2026-08-31', 'quiz-reset-log:derrick-jackson:TAB-B-102:2026-08-31'),
  ('Hakym Conejo', 'TAB-B-101', '2026-08-31', 'quiz-reset-log:hakym-conejo:TAB-B-101:2026-08-31'),
  ('Ryan Dinger', 'TAB-B-109', '2026-08-31', 'quiz-reset-log:ryan-dinger:TAB-B-109:2026-08-31'),
  ('Joshua Kropf', 'TAB-B-109', '2026-08-31', 'quiz-reset-log:joshua-kropf:TAB-B-109:2026-08-31'),
  ('David Summiel', 'TAB-B-108', '2026-09-04', 'quiz-reset-log:david-summiel:TAB-B-108:2026-09-04'),
  ('Cameron Smith', 'TAB-A-201', '2026-09-04', 'quiz-reset-log:cameron-smith:TAB-A-201:2026-09-04'),
  ('Paul Samuelson', 'TAB-B-111', '2026-09-09', 'quiz-reset-log:paul-samuelson:TAB-B-111:2026-09-09'),
  ('James Bell', 'TAB-B-109', '2026-09-17', 'quiz-reset-log:james-bell:TAB-B-109:2026-09-17'),
  ('James Bell', 'TAB-B-110', '2026-09-17', 'quiz-reset-log:james-bell:TAB-B-110:2026-09-17'),
  ('Luis Rosendo', 'TAB-B-310', '2026-09-18', 'quiz-reset-log:luis-rosendo:TAB-B-310:2026-09-18'),
  ('Clinton Duru', 'TAB-B-108', '2026-09-22', 'quiz-reset-log:clinton-duru:TAB-B-108:2026-09-22'),
  ('Derrick Jackson', 'TAB-B-105', '2026-09-22', 'quiz-reset-log:derrick-jackson:TAB-B-105:2026-09-22'),
  ('Andrew Lacobee', 'TAB-B-308', '2026-09-22', 'quiz-reset-log:andrew-lacobee:TAB-B-308:2026-09-22'),
  ('Angel Lopez', 'TAB-B-206', '2026-09-23', 'quiz-reset-log:angel-lopez:TAB-B-206:2026-09-23'),
  ('Jason Chinchilla', 'TAB-B-109', '2026-09-23', 'quiz-reset-log:jason-chinchilla:TAB-B-109:2026-09-23'),
  ('Bilardo Artiga', 'TAB-B-105', '2026-09-24', 'quiz-reset-log:bilardo-artiga:TAB-B-105:2026-09-24'),
  ('Ryan Dinger', 'TAB-B-111', '2026-09-25', 'quiz-reset-log:ryan-dinger:TAB-B-111:2026-09-25'),
  ('Ryan Dinger', 'TAB-B-301', '2026-09-25', 'quiz-reset-log:ryan-dinger:TAB-B-301:2026-09-25'),
  ('Mitchell Peterson', 'TAB-B-102', '2026-09-27', 'quiz-reset-log:mitchell-peterson:TAB-B-102:2026-09-27'),
  ('Mitchell Peterson', 'TAB-B-102', '2026-09-28', 'quiz-reset-log:mitchell-peterson:TAB-B-102:2026-09-28'),
  ('Austin Annunziata', 'TAB-B-101', '2026-09-28', 'quiz-reset-log:austin-annunziata:TAB-B-101:2026-09-28'),
  ('Austin Annunziata', 'TAB-B-102', '2026-09-28', 'quiz-reset-log:austin-annunziata:TAB-B-102:2026-09-28'),
  ('Chad Lorenz', 'TAB-B-107', '2026-09-28', 'quiz-reset-log:chad-lorenz:TAB-B-107:2026-09-28'),
  ('Jason Chinchilla', 'TAB-B-103', '2026-09-28', 'quiz-reset-log:jason-chinchilla:TAB-B-103:2026-09-28'),
  ('Javed Esa Mohammed', 'TAB-B-108', '2026-10-04', 'quiz-reset-log:javed-esa-mohammed:TAB-B-108:2026-10-04'),
  ('Andrew Lacobee', 'TAB-B-401', '2026-10-05', 'quiz-reset-log:andrew-lacobee:TAB-B-401:2026-10-05'),
  ('Javed Esa Mohammed', 'TAB-B-109', '2026-10-05', 'quiz-reset-log:javed-esa-mohammed:TAB-B-109:2026-10-05'),
  ('Luis Rosendo', 'TAB-B-309', '2026-10-06', 'quiz-reset-log:luis-rosendo:TAB-B-309:2026-10-06'),
  ('Angel Lopez', 'TAB-B-207', '2026-10-07', 'quiz-reset-log:angel-lopez:TAB-B-207:2026-10-07'),
  ('Evan Smith', 'TAB-B-108', '2026-10-07', 'quiz-reset-log:evan-smith:TAB-B-108:2026-10-07'),
  ('Chad Lorenz', 'TAB-B-108', '2026-10-08', 'quiz-reset-log:chad-lorenz:TAB-B-108:2026-10-08'),
  ('Sebastian Rosado', 'TAB-B-104', '2026-10-08', 'quiz-reset-log:sebastian-rosado:TAB-B-104:2026-10-08'),
  ('Sebastian Rosado', 'TAB-B-105', '2026-10-08', 'quiz-reset-log:sebastian-rosado:TAB-B-105:2026-10-08'),
  ('Paul Samuelson', 'TAB-B-301', '2026-10-08', 'quiz-reset-log:paul-samuelson:TAB-B-301:2026-10-08'),
  ('Cameron Smith', 'TAB-A-203', '2026-10-08', 'quiz-reset-log:cameron-smith:TAB-A-203:2026-10-08'),
  ('Bilardo Artiga', 'TAB-B-109', '2026-10-13', 'quiz-reset-log:bilardo-artiga:TAB-B-109:2026-10-13'),
  ('Clinton Duru', 'TAB-B-111', '2026-10-14', 'quiz-reset-log:clinton-duru:TAB-B-111:2026-10-14'),
  ('Derrick Jackson', 'TAB-B-108', '2026-10-14', 'quiz-reset-log:derrick-jackson:TAB-B-108:2026-10-14'),
  ('Chad Lorenz', 'TAB-B-108', '2026-10-15', 'quiz-reset-log:chad-lorenz:TAB-B-108:2026-10-15'),
  ('Jason Chinchilla', 'TAB-B-107', '2026-10-15', 'quiz-reset-log:jason-chinchilla:TAB-B-107:2026-10-15'),
  ('Paul Samuelson', 'TAB-B-301', '2026-10-16', 'quiz-reset-log:paul-samuelson:TAB-B-301:2026-10-16'),
  ('Austin Annunziata', 'TAB-B-108', '2026-10-16', 'quiz-reset-log:austin-annunziata:TAB-B-108:2026-10-16'),
  ('Ryan Dinger', 'TAB-B-307', '2026-10-18', 'quiz-reset-log:ryan-dinger:TAB-B-307:2026-10-18'),
  ('Evan Smith', 'TAB-B-110', '2026-10-20', 'quiz-reset-log:evan-smith:TAB-B-110:2026-10-20'),
  ('Austin Annunziata', 'TAB-B-108', '2026-10-20', 'quiz-reset-log:austin-annunziata:TAB-B-108:2026-10-20'),
  ('Clinton Duru', 'TAB-B-203', '2026-10-20', 'quiz-reset-log:clinton-duru:TAB-B-203:2026-10-20'),
  ('Cameron Smith', 'TAB-A-301', '2026-10-20', 'quiz-reset-log:cameron-smith:TAB-A-301:2026-10-20'),
  ('Sean Sutherland', 'TAB-A-301', '2026-10-21', 'quiz-reset-log:sean-sutherland:TAB-A-301:2026-10-21'),
  ('Nathan Cline', 'TAB-B-107', '2026-10-21', 'quiz-reset-log:nathan-cline:TAB-B-107:2026-10-21'),
  ('Jason Chinchilla', 'TAB-B-107', '2026-10-21', 'quiz-reset-log:jason-chinchilla:TAB-B-107:2026-10-21'),
  ('Sean Sutherland', 'TAB-A-302', '2026-10-22', 'quiz-reset-log:sean-sutherland:TAB-A-302:2026-10-22'),
  ('David Summiel', 'TAB-B-204', '2026-10-22', 'quiz-reset-log:david-summiel:TAB-B-204:2026-10-22');

INSERT INTO ata_attempts (tech_id, lesson_code, score_percent, passed, attempted_at, source, external_id)
SELECT t.id, s.lesson_code, NULL, false, (s.reset_on::text || ' 12:00:00-05')::timestamptz, 'manual_reset', s.external_id
FROM quiz_reset_log_src s
JOIN LATERAL (
  SELECT id FROM technicians
  WHERE deleted_at IS NULL AND lower(trim(name)) = lower(trim(s.tech_name))
  ORDER BY id
  LIMIT 1
) t ON true
WHERE NOT EXISTS (
  SELECT 1 FROM ata_attempts a
  WHERE a.external_id = s.external_id
     OR (
       a.tech_id = t.id
       AND a.lesson_code = s.lesson_code
       AND a.source = 'manual_reset'
       AND (a.attempted_at AT TIME ZONE 'America/Chicago')::date = s.reset_on
     )
);

SELECT s.tech_name, s.lesson_code, s.reset_on
FROM quiz_reset_log_src s
WHERE NOT EXISTS (
  SELECT 1 FROM technicians t
  WHERE t.deleted_at IS NULL AND lower(trim(t.name)) = lower(trim(s.tech_name))
)
ORDER BY s.tech_name, s.reset_on;
