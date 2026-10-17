-- Import NE Weekly Updates from Training Technician Skill Tracker Evaluation tabs
-- Safe to re-run: skips rows that already match tech+date+trainer+comment.
BEGIN;
INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
VALUES ('NE', 100, NULL)
ON CONFLICT (region, tech_id) DO UPDATE SET archived_at = NULL;
INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
VALUES ('NE', 101, NULL)
ON CONFLICT (region, tech_id) DO UPDATE SET archived_at = NULL;
INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
VALUES ('NE', 102, NULL)
ON CONFLICT (region, tech_id) DO UPDATE SET archived_at = NULL;
INSERT INTO public.weekly_update_roster (region, tech_id, archived_at)
VALUES ('NE', 103, NULL)
ON CONFLICT (region, tech_id) DO UPDATE SET archived_at = NULL;

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 100, DATE '2026-09-21', 11, NULL,
  'S', 'S', NULL, NULL, 'S',
  $w$James was hesitant to provide too much feedback. Mitch was nice and easy to work with but he had some concerns. The main concern is that he didn't ask a ton of questions or go out of his way to be curious and engaged. James was careful to say that he could see this being a personality thing but it held him back from giving a 100% positive review.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=100
    AND w.update_date=DATE '2026-09-21'
    AND w.trainer_tech_id=11
    AND coalesce(w.comment,'')=$w$James was hesitant to provide too much feedback. Mitch was nice and easy to work with but he had some concerns. The main concern is that he didn't ask a ton of questions or go out of his way to be curious and engaged. James was careful to say that he could see this being a personality thing but it held him back from giving a 100% positive review.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 100, DATE '2026-09-28', 9, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He's good. He's always early and willing to work. He did some systems on his own this week.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=100
    AND w.update_date=DATE '2026-09-28'
    AND w.trainer_tech_id=9
    AND coalesce(w.comment,'')=$w$He's good. He's always early and willing to work. He did some systems on his own this week.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 100, DATE '2026-10-05', 12, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Mitchell was great to work with. He is picking this up quickly and helping us move through apartments. By the end of the week he was doing a lot on his own. He could use a change of scenery and see something other than an apartment if we have it.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=100
    AND w.update_date=DATE '2026-10-05'
    AND w.trainer_tech_id=12
    AND coalesce(w.comment,'')=$w$Mitchell was great to work with. He is picking this up quickly and helping us move through apartments. By the end of the week he was doing a lot on his own. He could use a change of scenery and see something other than an apartment if we have it.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 100, DATE '2026-10-12', 12, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He seems willing to work and show up on time.If anything i think he still feeling everything out with airadigm and seems a little intimidated by the report and actually opening up the computer. Out of all the new guys i guess i would put him in the front of the pack$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=100
    AND w.update_date=DATE '2026-10-12'
    AND w.trainer_tech_id=12
    AND coalesce(w.comment,'')=$w$He seems willing to work and show up on time.If anything i think he still feeling everything out with airadigm and seems a little intimidated by the report and actually opening up the computer. Out of all the new guys i guess i would put him in the front of the pack$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 103, DATE '2026-09-21', 14, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Austin seems to have a good level of interest in learning the balancing process, I am a little concerned about his engagement however. I don't always expect much on week one, but Austin does not ask many questions and seems to learn the material on the slower side. After I show him a process and ask him to demonstrate, he needs more prompting to even start the task. I am cautiously optimistic about his future with Airadigm.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=103
    AND w.update_date=DATE '2026-09-21'
    AND w.trainer_tech_id=14
    AND coalesce(w.comment,'')=$w$Austin seems to have a good level of interest in learning the balancing process, I am a little concerned about his engagement however. I don't always expect much on week one, but Austin does not ask many questions and seems to learn the material on the slower side. After I show him a process and ask him to demonstrate, he needs more prompting to even start the task. I am cautiously optimistic about his future with Airadigm.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 103, DATE '2026-09-28', 10, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Austin was quiet to start the week but was willing to do what was asked. As the week progressed, i began to push Austin out of his comfort zone and challenge him to start performing tasks on his own or under my supervision. Once i began doing this, he appears to have "come out of his shell" so to speak. He was able to read units on his own while i was on the roof. Austin has exposure to many different tasks this week. The one bad point I will make is that he did not bring his iPad to work one day. He stated he forgot it on the charger at home.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=103
    AND w.update_date=DATE '2026-09-28'
    AND w.trainer_tech_id=10
    AND coalesce(w.comment,'')=$w$Austin was quiet to start the week but was willing to do what was asked. As the week progressed, i began to push Austin out of his comfort zone and challenge him to start performing tasks on his own or under my supervision. Once i began doing this, he appears to have "come out of his shell" so to speak. He was able to read units on his own while i was on the roof. Austin has exposure to many different tasks this week. The one bad point I will make is that he did not bring his iPad to work one day. He stated he forgot it on the charger at home.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 103, DATE '2026-09-28', 17, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He's smart and seems to be picking things up fairly quickly. Austin is a little more reserved than other guys so it could be tough to compare techs to each other. Overall he was great to work with. He's a good hire.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=103
    AND w.update_date=DATE '2026-09-28'
    AND w.trainer_tech_id=17
    AND coalesce(w.comment,'')=$w$He's smart and seems to be picking things up fairly quickly. Austin is a little more reserved than other guys so it could be tough to compare techs to each other. Overall he was great to work with. He's a good hire.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 103, DATE '2026-10-05', 17, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$We had a good day on site and I have nothing but good things to say about him. He's making good progress. He's not picking up everything quite as fast as Ryan Dinger or Jason but he's working at it and is definitely in a solid spot for only being here a month.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=103
    AND w.update_date=DATE '2026-10-05'
    AND w.trainer_tech_id=17
    AND coalesce(w.comment,'')=$w$We had a good day on site and I have nothing but good things to say about him. He's making good progress. He's not picking up everything quite as fast as Ryan Dinger or Jason but he's working at it and is definitely in a solid spot for only being here a month.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 103, DATE '2026-10-05', 7, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$I worked with him two days and he was good. We had a chance to do some normal constant volume stuff which was good for him to see. I don't have any major concerns at all with Austin at this point.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=103
    AND w.update_date=DATE '2026-10-05'
    AND w.trainer_tech_id=7
    AND coalesce(w.comment,'')=$w$I worked with him two days and he was good. We had a chance to do some normal constant volume stuff which was good for him to see. I don't have any major concerns at all with Austin at this point.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 103, DATE '2026-10-12', 7, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Dylan was impressed with his improvement. He seems to have a good understanding of things after asking questions. Takes fedback really well.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=103
    AND w.update_date=DATE '2026-10-12'
    AND w.trainer_tech_id=7
    AND coalesce(w.comment,'')=$w$Dylan was impressed with his improvement. He seems to have a good understanding of things after asking questions. Takes fedback really well.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 102, DATE '2026-09-21', 17, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Matt has a lot of good things to say about Jason. He has been on time and is very interested in learning the ins and outs of balancing.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=102
    AND w.update_date=DATE '2026-09-21'
    AND w.trainer_tech_id=17
    AND coalesce(w.comment,'')=$w$Matt has a lot of good things to say about Jason. He has been on time and is very interested in learning the ins and outs of balancing.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 102, DATE '2026-09-28', 17, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Always early. Very impressed by how much he cares. You see it with his tools, his vehicle, his equipment. He's very excited about this job and eager to keep taking the next steps. Dylan was there briefly and he echoes all of these sentiments. Dylan was impressed with the fact he could take water readings. He was picking things up quickly and able to help.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=102
    AND w.update_date=DATE '2026-09-28'
    AND w.trainer_tech_id=17
    AND coalesce(w.comment,'')=$w$Always early. Very impressed by how much he cares. You see it with his tools, his vehicle, his equipment. He's very excited about this job and eager to keep taking the next steps. Dylan was there briefly and he echoes all of these sentiments. Dylan was impressed with the fact he could take water readings. He was picking things up quickly and able to help.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 102, DATE '2026-10-05', 17, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$He has still been great to work with. I can't say enough good things about him. I also heard he's signed up to work Saturday and keeps asking for off-hours opportunities. He is eager to contribute.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=102
    AND w.update_date=DATE '2026-10-05'
    AND w.trainer_tech_id=17
    AND coalesce(w.comment,'')=$w$He has still been great to work with. I can't say enough good things about him. I also heard he's signed up to work Saturday and keeps asking for off-hours opportunities. He is eager to contribute.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 102, DATE '2026-10-12', 4, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Nothing bad to say about Jason. Punctual, polite, ready to work.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=102
    AND w.update_date=DATE '2026-10-12'
    AND w.trainer_tech_id=4
    AND coalesce(w.comment,'')=$w$Nothing bad to say about Jason. Punctual, polite, ready to work.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 102, DATE '2026-10-12', 14, NULL,
  'S', 'S', 'S', 'U', 'S',
  $w$I worked with Jason for four days this week. Jason shows up on time  no issue even for the long drives. I was surprised that he had not been shown the ATA app that much until working with me and also did not have much experience with using fan laws yet. It seems like he has drilled his first traverses with me as well. This isn't a knock on his abilities but more so over the training he has a received compared to the other technicians in this group. I have given a U for engagement this week due to Jason's tendency to pull his phone out to read when not immediately engaged. Particularly when I would talk with controls or mechanical about technical aspects of the job, he would sit off and browse his phone. Attitude was another point I was conflicted on. He's a good kid and is willing to learn everything, but is quick to complain when he job isn't going right - something we all do but this stuck out to me with Jason. He learns the skills well so I am still cautiously optimistic with Jason.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=102
    AND w.update_date=DATE '2026-10-12'
    AND w.trainer_tech_id=14
    AND coalesce(w.comment,'')=$w$I worked with Jason for four days this week. Jason shows up on time  no issue even for the long drives. I was surprised that he had not been shown the ATA app that much until working with me and also did not have much experience with using fan laws yet. It seems like he has drilled his first traverses with me as well. This isn't a knock on his abilities but more so over the training he has a received compared to the other technicians in this group. I have given a U for engagement this week due to Jason's tendency to pull his phone out to read when not immediately engaged. Particularly when I would talk with controls or mechanical about technical aspects of the job, he would sit off and browse his phone. Attitude was another point I was conflicted on. He's a good kid and is willing to learn everything, but is quick to complain when he job isn't going right - something we all do but this stuck out to me with Jason. He learns the skills well so I am still cautiously optimistic with Jason.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 101, DATE '2026-09-21', 3, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Andrew said it was a strong first day from Nathan. Nothing negative to note. He also added this later via text: He's solid. I wouldn't say he has any experience balancing. But he knows his way around a construction site. Knows about duct work and dampers. He's confident on a ladder and with a drill and tape measure. So those are all good attributes to have right off the bat. Nice kid too$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=101
    AND w.update_date=DATE '2026-09-21'
    AND w.trainer_tech_id=3
    AND coalesce(w.comment,'')=$w$Andrew said it was a strong first day from Nathan. Nothing negative to note. He also added this later via text: He's solid. I wouldn't say he has any experience balancing. But he knows his way around a construction site. Knows about duct work and dampers. He's confident on a ladder and with a drill and tape measure. So those are all good attributes to have right off the bat. Nice kid too$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 101, DATE '2026-09-28', 19, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Stays ahead of the lead technician , learnng the physical side very fast. Needs a little work on the computer. Sean indicates he thinks he is going to be a great balancer if he keeps it up!$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=101
    AND w.update_date=DATE '2026-09-28'
    AND w.trainer_tech_id=19
    AND coalesce(w.comment,'')=$w$Stays ahead of the lead technician , learnng the physical side very fast. Needs a little work on the computer. Sean indicates he thinks he is going to be a great balancer if he keeps it up!$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 101, DATE '2026-10-05', 9, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$I worked with Nathan on Monday and Tuesday. We ended up doing a lot of water troubleshooting because that is what the customer needed but he stayed engaged and interested. Then Tuesday we ran into some airflow issues and bounced to a second project. Overall it was good and he had a good attitude. I just can't really speak to his skills at this point yet.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=101
    AND w.update_date=DATE '2026-10-05'
    AND w.trainer_tech_id=9
    AND coalesce(w.comment,'')=$w$I worked with Nathan on Monday and Tuesday. We ended up doing a lot of water troubleshooting because that is what the customer needed but he stayed engaged and interested. Then Tuesday we ran into some airflow issues and bounced to a second project. Overall it was good and he had a good attitude. I just can't really speak to his skills at this point yet.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 101, DATE '2026-10-05', 3, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$I basically let Nathan run the show. He ran the iPad and directed me what to read next and then I would let him make the adjustments. It was a lot of constant volume stuff and he did a great job with it.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=101
    AND w.update_date=DATE '2026-10-05'
    AND w.trainer_tech_id=3
    AND coalesce(w.comment,'')=$w$I basically let Nathan run the show. He ran the iPad and directed me what to read next and then I would let him make the adjustments. It was a lot of constant volume stuff and he did a great job with it.$w$
);

INSERT INTO public.weekly_updates (
  region, tech_id, update_date, trainer_tech_id, trainer_tech_id_2,
  rating_punctuality, rating_attitude, rating_effort, rating_engagement, rating_teamwork,
  comment, action_plan
)
SELECT
  'NE', 101, DATE '2026-10-12', 11, NULL,
  'S', 'S', 'S', 'S', 'S',
  $w$Only worked day and half with him. Not much feedback for you other than he’s got drive.$w$, NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.weekly_updates w
  WHERE w.region='NE' AND w.tech_id=101
    AND w.update_date=DATE '2026-10-12'
    AND w.trainer_tech_id=11
    AND coalesce(w.comment,'')=$w$Only worked day and half with him. Not much feedback for you other than he’s got drive.$w$
);

SELECT t.name AS tech, w.update_date, tr.name AS trainer,
  w.rating_punctuality, w.rating_attitude, w.rating_effort, w.rating_engagement, w.rating_teamwork,
  left(w.comment, 60) AS comment_preview
FROM public.weekly_updates w
JOIN public.technicians t ON t.id=w.tech_id
LEFT JOIN public.technicians tr ON tr.id=w.trainer_tech_id
WHERE w.region='NE' AND w.tech_id IN (100,101,102,103)
ORDER BY t.name, w.update_date, w.id;

COMMIT;