-- Employment start dates from May 2026 assignments PDF.
-- Run in Supabase -> SQL Editor. Safe to re-run (idempotent).
--
-- Source: May 2026 assignments.pdf (HR roster start dates)
-- Not in technicians table (skipped): Berrios, Samuelson, Turner, Lorenz, Lopez, Matthew Michels

ALTER TABLE public.technicians
  ADD COLUMN IF NOT EXISTS start_date date;

UPDATE public.technicians t
SET start_date = v.start_date::date
FROM (VALUES
  ('Adam Freeman', '2023-05-30'),
  ('Alex Baichu', '2024-09-16'),
  ('Alex Barajas', '2025-09-02'),
  ('Alfredo Salas', '2018-08-05'),
  ('Anatoliy Ilyuk', '2013-05-20'),
  ('Andres Bohorquez', '2026-03-31'),
  ('Andrew Lacobee', '2026-02-10'),
  ('Andrew Parziale', '2015-02-02'),
  ('Austin Winters', '2025-05-27'),
  ('Brian Randolph', '2025-06-23'),
  ('Cameron Smith', '2025-06-23'),
  ('Chris Conejo', '2025-01-06'),
  ('Corey Crockett', '2021-03-29'),
  ('Corey Sharrow', '2021-01-27'),
  ('Daniel Lemus', '2024-06-03'),
  ('DeAndre Black', '2025-09-02'),
  ('Dom Jean-Louis', '2026-01-06'),
  ('Don Beauchesne', '2021-03-15'),
  ('Dylan Conner', '2015-05-11'),
  ('Eric Olson', '2015-10-26'),
  ('Eric Watkins', '2008-10-13'),
  ('Frederic Bahati', '2024-06-24'),
  ('Gary St. Clair', '2021-11-29'),
  ('Grant Gugel', '2025-08-05'),
  ('Henry Boyle', '2025-11-04'),
  ('James Dupass', '2015-04-14'),
  ('Jef Tucker', '2001-01-06'),
  ('Jeremy Wickson', '2022-01-31'),
  ('Jimmy Anderson', '2020-08-17'),
  ('Joe Figone', '2025-04-28'),
  ('Jonathan Gonzalez', '2025-11-04'),
  ('Jonny Cascarano', '2025-07-14'),
  ('Josh Earle', '2025-06-30'),
  ('Josh Stepnick', '2019-01-07'),
  ('Justin Bowman', '2026-02-24'),
  ('Justin Holton', '2026-02-24'),
  ('Keith Parker', '2025-09-02'),
  ('Kody Collins', '2019-05-13'),
  ('Kurt Paradis', '2020-10-05'),
  ('Leonardo Cruz', '2024-03-18'),
  ('Luis Rosendo', '2025-11-04'),
  ('Marco Gaspar', '2019-04-08'),
  ('Matt O''Brien', '2014-05-17'),
  ('Nicholas Gray', '2025-08-05'),
  ('Phillip Michels', '2024-06-03'),
  ('Richard Wilson', '2025-09-02'),
  ('Sean Sutherland', '2025-10-07'),
  ('Shane Reich', '2023-01-09'),
  ('Stavros Themeilis', '2015-08-28'),
  ('Stranten Seui-Purdy', '2024-07-29'),
  ('Thomas Ryan', '2023-11-06'),
  ('Tim Bollinger', '2025-11-04'),
  ('Tristan Taylor', '2024-03-18'),
  ('Tyler LeBlanc', '2025-06-05'),
  ('Vinny Fitzpatrick', '2021-04-12'),
  ('Wayne Hamilton', '2024-11-11'),
  ('Zander Caron-Mitchell', '2025-12-09')
) AS v(name, start_date)
WHERE lower(trim(t.name)) = lower(trim(v.name));

-- Verify: technicians still missing a start date
SELECT id, name, region
FROM public.technicians
WHERE deleted_at IS NULL
  AND start_date IS NULL
ORDER BY name;

