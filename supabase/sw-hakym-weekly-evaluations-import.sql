-- Import SW Weekly Updates: Hakym Conejo Evaluation tab
BEGIN;
INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
VALUES ('SW', 84, NULL)
ON CONFLICT (region, tech_id) DO UPDATE SET archived_at = NULL;

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'SW', 84, DATE '2026-09-11', 37, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He is starting off like many others. If you don't give him something he will sit and wait instead of asking. We are working mainly on grille balancing and have not delved much into other things. I want to get him where he can get a 10 grille system under and hour. He  is missing the key grille at times which has us going back to re-balance the system. He is coming along and seems to be grasping the concepts.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='SW' AND w.tech_id=84
    AND w.update_date=DATE '2026-09-11'
    AND w.trainer_tech_id=37
    AND coalesce(w.comment,'')=$w$He is starting off like many others. If you don't give him something he will sit and wait instead of asking. We are working mainly on grille balancing and have not delved much into other things. I want to get him where he can get a 10 grille system under and hour. He  is missing the key grille at times which has us going back to re-balance the system. He is coming along and seems to be grasping the concepts.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'SW', 84, DATE '2026-09-18', 37, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He needs to focus on all aspects of the actual balancing process. His accuracy is good but he does need to increase his speed. It's still early so the pacing will come. When obtaining unit info he took the motor data from the compressor fan and called the units direct drive. We will work on this more. I am still of the belief that he will be just fine.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='SW' AND w.tech_id=84
    AND w.update_date=DATE '2026-09-18'
    AND w.trainer_tech_id=37
    AND coalesce(w.comment,'')=$w$He needs to focus on all aspects of the actual balancing process. His accuracy is good but he does need to increase his speed. It's still early so the pacing will come. When obtaining unit info he took the motor data from the compressor fan and called the units direct drive. We will work on this more. I am still of the belief that he will be just fine.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'SW', 84, DATE '2026-10-02', 37, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He worked with Marco this week.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='SW' AND w.tech_id=84
    AND w.update_date=DATE '2026-10-02'
    AND w.trainer_tech_id=37
    AND coalesce(w.comment,'')=$w$He worked with Marco this week.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'SW', 84, DATE '2026-10-09', 37, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He needs to work on making sure all blanks are filled in. I had him do the coil face on a project. He did the work and I filled out the form. It was the first one we have done. On the next one I will have him do the entire thing on his own and just watch. His balancing is progressing but he needs to focus on all aspects of one system. As with any new tech I believe he will progress into a nice asset.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='SW' AND w.tech_id=84
    AND w.update_date=DATE '2026-10-09'
    AND w.trainer_tech_id=37
    AND coalesce(w.comment,'')=$w$He needs to work on making sure all blanks are filled in. I had him do the coil face on a project. He did the work and I filled out the form. It was the first one we have done. On the next one I will have him do the entire thing on his own and just watch. His balancing is progressing but he needs to focus on all aspects of one system. As with any new tech I believe he will progress into a nice asset.$w$
);

SELECT t.name AS tech, w.update_date, tr.name AS trainer,
  w.rating_punctuality, w.rating_attitude, w.rating_effort, w.rating_engagement, w.rating_teamwork,
  left(w.comment, 80) AS comment_preview
FROM public.weekly_updates w
JOIN public.technicians t ON t.id=w.tech_id
LEFT JOIN public.technicians tr ON tr.id=w.trainer_tech_id
WHERE w.region='SW' AND w.tech_id=84
ORDER BY w.update_date, w.id;

COMMIT;