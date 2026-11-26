-- A symptom diary for the demo patient Alex, who also has IBS: bloating and gas a few hours after most
-- of his afternoon yogurt snacks, two milder days after the breakfast burrito, and loose stools once.
-- Run once after seed.sql and migration 0007; re-running does nothing. The entries are placed after
-- Alex's logged meals, so demo_refresh.sql moving the diary forward moves them too.
do $$
declare
  alex constant uuid := 'a0000000-0000-4000-8000-000000000004';
begin
  if exists (select 1 from symptom_logs where user_id = alex) then
    raise notice 'Demo symptoms already exist';
    return;
  end if;

  update profiles set conditions = array_append(conditions, 'ibs')
   where id = alex and not ('ibs' = any(conditions));

  -- 8 of the yogurt snacks (15:30) are followed by symptoms about 3 hours later.
  insert into symptom_logs (user_id, logged_at, symptoms, severity, bristol, note)
  select alex, f.logged_at + interval '3 hours 10 minutes',
    case when f.n % 3 = 0 then '{bloating,gas,abdominal_pain}'::text[] else '{bloating,gas}'::text[] end,
    case when f.n = 2 then 8 else 4 + f.n % 4 end,  -- one severe evening for the doctor's flags
    case when f.n = 4 then 6 end,
    case when f.n = 1 then 'Worse than usual after the gym' end
  from (select logged_at, row_number() over (order by logged_at desc) as n
          from food_logs where user_id = alex and name = 'Greek yogurt with granola') f
  where f.n <= 8;

  -- Two milder mornings after the breakfast burrito.
  insert into symptom_logs (user_id, logged_at, symptoms, severity)
  select alex, f.logged_at + interval '2 hours', '{bloating}', 3
  from (select logged_at, row_number() over (order by logged_at desc) as n
          from food_logs where user_id = alex and name = 'Breakfast burrito') f
  where f.n in (2, 6);
end $$;
