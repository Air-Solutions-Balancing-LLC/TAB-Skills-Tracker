-- Import National Weekly Updates: Javed Mohammed Evaluation tab
BEGIN;
INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
VALUES ('National', 88, NULL)
ON CONFLICT (region, tech_id) DO UPDATE SET archived_at = NULL;

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'National', 88, DATE '2026-08-24', 50, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Javed had an overall great additude - he was punctual ,  we communicated well and he had a good understanding of what we were working on. He helped enter information into apparatus sheets and outlet sheets . He measured supply, exhaust diffusers and kitchen hood baffles.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='National' AND w.tech_id=88
    AND w.update_date=DATE '2026-08-24'
    AND w.trainer_tech_id=50
    AND coalesce(w.comment,'')=$w$Javed had an overall great additude - he was punctual ,  we communicated well and he had a good understanding of what we were working on. He helped enter information into apparatus sheets and outlet sheets . He measured supply, exhaust diffusers and kitchen hood baffles.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'National', 88, DATE '2026-09-03', 57, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Has great attitude and willingness to learn each part of the job. Follows instructions and doesn't hesitate to ask questions to get better understanding of scope of work.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='National' AND w.tech_id=88
    AND w.update_date=DATE '2026-09-03'
    AND w.trainer_tech_id=57
    AND coalesce(w.comment,'')=$w$Has great attitude and willingness to learn each part of the job. Follows instructions and doesn't hesitate to ask questions to get better understanding of scope of work.$w$
);

SELECT t.name AS tech, w.update_date, tr.name AS trainer,
  w.rating_punctuality, w.rating_attitude, w.rating_effort, w.rating_engagement, w.rating_teamwork,
  left(w.comment, 80) AS comment_preview
FROM public.weekly_updates w
JOIN public.technicians t ON t.id=w.tech_id
LEFT JOIN public.technicians tr ON tr.id=w.trainer_tech_id
WHERE w.region='National' AND w.tech_id=88
ORDER BY w.update_date, w.id;

COMMIT;