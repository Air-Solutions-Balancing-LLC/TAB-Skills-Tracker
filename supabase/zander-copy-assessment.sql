-- Copy / reassign skills assessments from the archived duplicate Zander
-- onto the active Zander Caron-Mitchell.
--
-- Run once in Supabase → SQL Editor.
-- Safe to re-run: already-moved rows stay on the active tech; same-date
-- conflicts keep the active row and skip the archived duplicate.
-- Assessments in this database use technician_id only (no tech_id column).

-- ── 1) Preview both Zander rows ───────────────────────────────────────────────
SELECT
  t.id,
  t.name,
  t.email,
  t.region,
  t.deleted_at,
  CASE WHEN t.deleted_at IS NULL THEN 'ACTIVE' ELSE 'ARCHIVED' END AS status,
  (SELECT count(*) FROM public.assessments a WHERE a.technician_id = t.id) AS assessment_count
FROM public.technicians t
WHERE lower(t.name) LIKE '%zander%'
ORDER BY t.deleted_at NULLS FIRST, t.id;

-- ── 2) Move assessments archived → active ─────────────────────────────────────
DO $$
DECLARE
  v_active   bigint;
  v_archived bigint;
  v_active_n int;
  v_arch_n   int;
  v_moved    int := 0;
  v_skipped  int := 0;
  r          record;
  v_exists   boolean;
BEGIN
  SELECT count(*) INTO v_active_n
  FROM public.technicians
  WHERE deleted_at IS NULL AND lower(name) LIKE '%zander%';

  SELECT count(*) INTO v_arch_n
  FROM public.technicians
  WHERE deleted_at IS NOT NULL AND lower(name) LIKE '%zander%';

  IF v_active_n <> 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 active Zander, found %', v_active_n;
  END IF;
  IF v_arch_n < 1 THEN
    RAISE EXCEPTION 'Expected at least 1 archived Zander, found %', v_arch_n;
  END IF;

  SELECT id INTO v_active
  FROM public.technicians
  WHERE deleted_at IS NULL AND lower(name) LIKE '%zander%'
  ORDER BY id
  LIMIT 1;

  -- Prefer the most recently archived duplicate
  SELECT id INTO v_archived
  FROM public.technicians
  WHERE deleted_at IS NOT NULL AND lower(name) LIKE '%zander%'
  ORDER BY deleted_at DESC, id DESC
  LIMIT 1;

  IF v_active IS NULL OR v_archived IS NULL OR v_active = v_archived THEN
    RAISE EXCEPTION 'Could not resolve distinct active/archived Zander ids';
  END IF;

  FOR r IN
    SELECT a.id, a.date
    FROM public.assessments a
    WHERE a.technician_id = v_archived
    ORDER BY a.date, a.id
  LOOP
    SELECT EXISTS (
      SELECT 1
      FROM public.assessments a2
      WHERE a2.date = r.date
        AND a2.technician_id = v_active
    ) INTO v_exists;

    IF v_exists THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    UPDATE public.assessments
       SET technician_id = v_active
     WHERE id = r.id;

    v_moved := v_moved + 1;
  END LOOP;

  RAISE NOTICE 'Active Zander id=% | Archived Zander id=% | moved=% | skipped_same_date=%',
    v_active, v_archived, v_moved, v_skipped;
END $$;

-- ── 3) Confirm ────────────────────────────────────────────────────────────────
SELECT
  t.id,
  t.name,
  CASE WHEN t.deleted_at IS NULL THEN 'ACTIVE' ELSE 'ARCHIVED' END AS status,
  a.id AS assessment_id,
  a.date,
  a.safety_avg,
  a.basic_avg,
  a.intermediate_avg,
  a.advanced_avg
FROM public.technicians t
LEFT JOIN public.assessments a ON a.technician_id = t.id
WHERE lower(t.name) LIKE '%zander%'
ORDER BY t.deleted_at NULLS FIRST, a.date NULLS LAST;
