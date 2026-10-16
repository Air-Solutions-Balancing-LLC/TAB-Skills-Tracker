-- Convert legacy skill proficiency Exceptional (5) → Proficient (4).
-- Does NOT change Survey / National Accounts job-count ratings (those keep 1–5).
-- Safe to re-run.

WITH skill_keys AS (
  SELECT sk.skill_code
  FROM public.skills sk
  JOIN public.skill_sections sec ON sec.id = sk.section_id
  WHERE coalesce(sec.section_type, 'rated') = 'rated'
    AND sec.skey NOT IN ('survey', 'national_accounts', 'basic_solo_projects', 'basic_survey_projects', 'orientation', 'pre_bootcamp')
),
rewritten AS (
  SELECT a.ctid AS row_ctid,
         (
           SELECT coalesce(jsonb_object_agg(e.key, CASE
             WHEN e.key IN (SELECT skill_code FROM skill_keys)
                  AND (
                    (jsonb_typeof(e.value) = 'number' AND (e.value #>> '{}')::numeric = 5)
                    OR (jsonb_typeof(e.value) = 'string'
                        AND trim(e.value #>> '{}') ~ '^[0-9]+(\.[0-9]+)?$'
                        AND (trim(e.value #>> '{}'))::numeric = 5)
                  )
               THEN to_jsonb(4)
             ELSE e.value
           END), '{}'::jsonb)
           FROM jsonb_each(coalesce(a.raw_scores::jsonb, '{}'::jsonb)) AS e
         ) AS new_raw
  FROM public.assessments a
  WHERE a.raw_scores IS NOT NULL
)
UPDATE public.assessments a
   SET raw_scores = r.new_raw::json
  FROM rewritten r
 WHERE a.ctid = r.row_ctid
   AND coalesce(a.raw_scores::jsonb, '{}'::jsonb) IS DISTINCT FROM r.new_raw;

UPDATE public.assessments
   SET safety_avg = LEAST(safety_avg, 4),
       basic_avg = LEAST(basic_avg, 4),
       intermediate_avg = LEAST(intermediate_avg, 4),
       advanced_avg = LEAST(advanced_avg, 4)
 WHERE (safety_avg IS NOT NULL AND safety_avg > 4)
    OR (basic_avg IS NOT NULL AND basic_avg > 4)
    OR (intermediate_avg IS NOT NULL AND intermediate_avg > 4)
    OR (advanced_avg IS NOT NULL AND advanced_avg > 4);
