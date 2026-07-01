-- Import KES technician assessments from Microsoft Forms export
-- Source: Suvery Responses -Skills Self-Assessment (4) (1).xlsx
-- PREREQ: run supabase/assessments-rpcs.sql first — or use kes-assessments-fix-now.sql (all-in-one).
-- Safe to re-run. No temp tables. No ON CONFLICT.

-- === IMPORT DATA ===
SELECT app_upsert_assessment_for_tech(
  app_match_technician_id(v.tech_name, 'KES'),
  CASE
    WHEN v.mode = 'latest' THEN coalesce(
      (SELECT max(a.date)
       FROM public.assessments a
       WHERE a.technician_id = app_match_technician_id(v.tech_name, 'KES')),
      v.fallback_date::date
    )
    ELSE v.assessment_date::date
  END,
  v.safety_avg,
  v.basic_avg,
  v.intermediate_avg,
  v.advanced_avg,
  v.survey_avg,
  v.comment,
  v.raw_scores
)
FROM (VALUES
  ('Alex Barajas', 'dated', '2026-03-28', '2025-09-30', 4.23, 4.55, NULL, NULL, NULL, NULL, '{"s1":5,"s2":4,"s3":5,"s4":5,"s5":2,"s6":4,"s7":4,"s8":5,"s9":3,"s10":4,"s11":5,"s12":4,"s13":5,"b1":5,"b2":5,"b3":5,"b4":5,"b5":5,"b6":5,"b7":5,"b8":5,"b9":5,"b10":3,"b11":5,"b12":5,"b13":5,"b14":5,"b15":5,"b16":4,"b17":5,"b18":5,"b19":5,"b20":5,"b21":3,"b22":3,"b23":5,"b24":5,"b25":5,"b26":5,"b27":5,"b28":2,"b29":3,"b30":5,"b31":5,"b32":5,"b33":4,"b34":5,"b35":5,"b36":3,"b37":3,"b38":5}'::jsonb),
  ('Paul Samuelson', 'dated', '2026-05-06', '2026-05-06', 2.62, 2.26, 1.7, 1.04, 1, NULL, '{"s1":2,"s2":2,"s3":1,"s4":3,"s5":2,"s6":3,"s7":3,"s8":3,"s9":3,"s10":3,"s11":3,"s12":3,"s13":3,"b1":1,"b2":2,"b3":2,"b4":2,"b5":1,"b6":2,"b7":2,"b8":2,"b9":4,"b10":1,"b11":1,"b12":3,"b13":3,"b14":1,"b15":4,"b16":3,"b17":4,"b18":4,"b19":2,"b20":1,"b21":1,"b22":1,"b23":4,"b24":2,"b25":4,"b26":3,"b27":3,"b28":1,"b29":3,"b30":1,"b31":2,"b32":4,"b33":2,"b34":2,"b35":2,"b36":1,"b37":1,"b38":4,"i2":2,"i3":1,"i4":1,"i5":1,"i6":3,"i7":4,"i8":1,"i9":3,"i10":4,"i11":2,"i12":1,"i13":1,"i14":1,"i15":1,"i16":4,"i17":4,"i18":4,"i19":4,"i20":1,"i21":2,"i22":1,"i23":1,"i24":2,"i25":1,"i26":1,"i27":1,"i28":1,"i29":1,"i30":1,"i31":1,"i32":1,"i33":1,"i34":1,"i35":1,"i36":1,"i37":1,"i38":1,"i39":1,"i40":1,"i41":3,"i42":2,"i43":1,"i44":2,"a1":2,"a3":1,"a4":1,"a5":1,"a6":1,"a7":1,"a8":1,"a9":1,"a10":1,"a11":1,"a12":1,"a13":1,"a14":1,"a15":1,"a16":1,"a17":1,"a18":1,"a19":1,"a20":1,"a21":1,"a22":1,"a23":1,"a24":1,"a25":1,"a26":1,"a27":1,"a28":1,"sv1":1,"sv2":1}'::jsonb),
  ('John Turner', 'dated', '2026-05-07', '2026-05-07', 5, 4.79, 4.37, 2.22, 2, NULL, '{"s1":5,"s2":5,"s3":5,"s4":5,"s5":5,"s6":5,"s7":5,"s8":5,"s9":5,"s10":5,"s11":5,"s12":5,"s13":5,"b1":5,"b2":5,"b3":5,"b4":5,"b5":5,"b6":5,"b7":5,"b8":5,"b9":5,"b10":3,"b11":5,"b12":5,"b13":5,"b14":5,"b15":5,"b16":5,"b17":5,"b18":5,"b19":5,"b20":5,"b21":3,"b22":5,"b23":5,"b24":5,"b25":5,"b26":5,"b27":5,"b28":3,"b29":5,"b30":5,"b31":5,"b32":5,"b33":5,"b34":5,"b35":5,"b36":3,"b37":5,"b38":5,"i2":5,"i3":5,"i4":5,"i5":5,"i6":5,"i7":5,"i8":5,"i9":5,"i10":5,"i11":5,"i12":5,"i13":3,"i14":5,"i15":5,"i16":5,"i17":5,"i18":5,"i19":5,"i20":3,"i21":5,"i22":5,"i23":3,"i24":5,"i25":3,"i26":3,"i27":3,"i28":3,"i29":3,"i30":3,"i31":3,"i32":5,"i33":5,"i34":5,"i35":5,"i36":5,"i37":5,"i38":5,"i39":2,"i40":3,"i41":5,"i42":5,"i43":3,"i44":5,"a1":5,"a3":2,"a4":2,"a5":2,"a6":2,"a7":2,"a8":2,"a9":3,"a10":1,"a11":2,"a12":2,"a13":2,"a14":2,"a15":2,"a16":3,"a17":2,"a18":2,"a19":2,"a20":2,"a21":2,"a22":2,"a23":4,"a24":2,"a25":2,"a26":2,"a27":2,"a28":2,"sv1":2,"sv2":2}'::jsonb),
  ('Zander Caron-Mitchell', 'dated', '2026-03-30', NULL, 4.62, 3.13, 1.68, 1, NULL, NULL, '{"s1":5,"s2":5,"s3":4,"s4":5,"s5":4,"s6":5,"s7":5,"s8":5,"s9":5,"s10":4,"s11":5,"s12":5,"s13":3,"b1":3,"b2":3,"b3":2,"b4":3,"b5":3,"b6":2,"b7":5,"b8":2,"b9":4,"b10":1,"b11":4,"b12":4,"b13":4,"b14":4,"b15":4,"b16":4,"b17":5,"b18":4,"b19":4,"b20":4,"b21":1,"b22":1,"b23":4,"b24":4,"b25":4,"b26":4,"b27":4,"b28":1,"b29":1,"b30":3,"b31":1,"b32":4,"b33":4,"b34":4,"b35":4,"b36":1,"b37":1,"b38":4,"i2":1,"i3":1,"i4":1,"i5":1,"i6":4,"i7":4,"i8":1,"i9":3,"i10":4,"i11":1,"i13":1,"i14":1,"i15":1,"i16":4,"i17":4,"i18":4,"i19":3,"i20":1,"i21":2,"i22":1,"i23":1,"i24":3,"i25":1,"i26":1,"i27":1,"i28":1,"i29":1,"i30":1,"i31":1,"i32":1,"i33":1,"i35":1,"i36":3,"i37":1,"i38":1,"i39":1,"i40":1,"i41":2,"i42":1,"i43":1,"i44":1,"a1":1}'::jsonb)
) AS v(tech_name, mode, assessment_date, fallback_date, safety_avg, basic_avg, intermediate_avg, advanced_avg, survey_avg, comment, raw_scores)
WHERE app_match_technician_id(v.tech_name, 'KES') IS NOT NULL;

-- Verify
SELECT 'sample_latest' AS check_name, t.name, max(a.date) AS latest_date, count(*) AS total
FROM public.technicians t
JOIN public.assessments a ON a.technician_id = t.id
WHERE t.region = 'KES' AND t.deleted_at IS NULL
GROUP BY t.id, t.name
ORDER BY t.name;

SELECT 'june_2026_count' AS check_name, count(*) AS row_count
FROM public.assessments a
JOIN public.technicians t ON a.technician_id = t.id
WHERE t.region = 'KES' AND t.deleted_at IS NULL AND a.date >= '2026-06-01';
