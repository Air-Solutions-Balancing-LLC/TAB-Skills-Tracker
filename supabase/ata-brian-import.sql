-- One-off import of Brian Randolph's ATA quiz completions.
-- Source: "Brian Randolph - Digital ATA Scores.xlsx" (SharePoint). Run in Supabase
-- SQL Editor AFTER supabase/ata-tracking.sql. Safe to re-run (upserts by lesson).
-- Matches the technician by name; edit the name below if it differs in your data.

DO $$
DECLARE
  v_tid bigint;
BEGIN
  SELECT id INTO v_tid
  FROM public.technicians
  WHERE lower(trim(name)) = lower('Brian Randolph') AND deleted_at IS NULL
  LIMIT 1;

  IF v_tid IS NULL THEN
    RAISE EXCEPTION 'Technician "Brian Randolph" not found in public.technicians';
  END IF;

  INSERT INTO public.ata_completions (tech_id, lesson_code, score_percent, completed_at, source_email, updated_at) VALUES
  (v_tid, 'TAB-B-205', 91.7, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-301', 81.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-306', 95, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-307', 90.9, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-309', 81.8, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-106', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-108', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-109', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-111', 91.7, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-112', 89.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-206', 92.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-207', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-208', 82.4, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-209', NULL, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-210', 80.6, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-302', 89.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-303', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-304', 80, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-305', 84.6, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-308', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-310', 85.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-401', 86.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-B-402', 86.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-101', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-102', NULL, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-103', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-104', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-105', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-106', 83.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-107', 85.7, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-108', NULL, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-109', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-201', 90.9, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-202', 91.7, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-203', 92.9, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-204', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-205', 94.1, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-206', 91.7, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-207', 90.2, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-301', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-302', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-303', NULL, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-304', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-305', 92.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-306', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-307', 96.7, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-401', 93.3, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-402', 87.5, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-403', 100, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-404', NULL, NULL, 'Digital ATA Scores (xlsx)', now()),
  (v_tid, 'TAB-I-406', 87.5, NULL, 'Digital ATA Scores (xlsx)', now())
  ON CONFLICT (tech_id, lesson_code) DO UPDATE
    SET score_percent = EXCLUDED.score_percent,
        source_email  = EXCLUDED.source_email,
        updated_at    = now();

  RAISE NOTICE 'Imported % completed lessons for Brian Randolph (tech_id %)', 51, v_tid;
END $$;
