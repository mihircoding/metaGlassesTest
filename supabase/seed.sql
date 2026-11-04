-- NutraVision demo data: 1 doctor + 3 patients, password 'demo1234'. Runs as postgres (SQL editor) or the test owner.
-- Fixed UUIDs: re-running fails on the primary key instead of duplicating.
-- Targets below equal TargetCalculator output for each persona's stats (age as of 2026-11-04).

-- ---------------------------------------------------------------- auth users
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token)
select '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  extensions.crypt('demo1234', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('role', u.role, 'full_name', u.full_name),
  now(), now(), '', '', '', ''
from (values
  ('a0000000-0000-4000-8000-000000000001'::uuid, 'doctor@nutravision.demo', 'doctor', 'Dr. Priya Shah'),
  ('a0000000-0000-4000-8000-000000000002'::uuid, 'maria@nutravision.demo',  'patient', 'Maria Lopez'),
  ('a0000000-0000-4000-8000-000000000003'::uuid, 'james@nutravision.demo',  'patient', 'James Carter'),
  ('a0000000-0000-4000-8000-000000000004'::uuid, 'alex@nutravision.demo',   'patient', 'Alex Kim')
) as u(id, email, role, full_name);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text, jsonb_build_object('sub', id::text, 'email', email), 'email', now(), now(), now()
from auth.users;

-- ---------------------------------------------------------------- profiles (created by trigger; update only)
update profiles set specialty = 'Endocrinology', license_number = 'MD-48213'
 where id = 'a0000000-0000-4000-8000-000000000001';

-- Maria: F, 1968-03-15 (58), 165 cm, 82 kg, light, -0.4 kg/wk -> 1400.25*1.375-440 = 1485 -> 1490 kcal
update profiles set birth_date = '1968-03-15', sex = 'female', height_cm = 165, weight_kg = 82, activity = 'light',
  conditions = '{t2_diabetes}', goal_weight_kg = 74, weekly_rate_kg = -0.4,
  kcal_target = 1490, protein_g = 93, carbs_g = 149, fat_g = 58, sat_fat_g = 17, sodium_mg = 2300, fiber_g = 30
 where id = 'a0000000-0000-4000-8000-000000000002';

-- James: M, 1971-08-20 (55), 178 cm, 96 kg, light, -0.5 kg/wk -> 1802.5*1.375-550 = 1928 -> 1930 kcal
update profiles set birth_date = '1971-08-20', sex = 'male', height_cm = 178, weight_kg = 96, activity = 'light',
  conditions = '{hypertension}', goal_weight_kg = 88, weekly_rate_kg = -0.5,
  kcal_target = 1930, protein_g = 87, carbs_g = 265, fat_g = 58, sat_fat_g = 13, sodium_mg = 1500, fiber_g = 30
 where id = 'a0000000-0000-4000-8000-000000000003';

-- Alex: M, 1999-06-10 (27), 180 cm, 79 kg, very, +0.25 kg/wk -> 1780*1.725+275 = 3345.5 -> 3350 kcal
update profiles set birth_date = '1999-06-10', sex = 'male', height_cm = 180, weight_kg = 79, activity = 'very',
  conditions = '{bodybuilding}', goal_weight_kg = 84, weekly_rate_kg = 0.25,
  kcal_target = 3350, protein_g = 251, carbs_g = 377, fat_g = 93, sat_fat_g = 37, sodium_mg = 2300, fiber_g = 30
 where id = 'a0000000-0000-4000-8000-000000000004';

-- ---------------------------------------------------------------- care links, recommendation
insert into care_links (doctor_id, patient_id, patient_email, status, responded_at)
select 'a0000000-0000-4000-8000-000000000001', id, email, 'accepted', now() - interval '40 days'
from profiles where role = 'patient';

insert into recommendations (doctor_id, patient_id, kind, payload, message, status)
values ('a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'targets',
  '{"targets":{"kcal_target":1900,"protein_g":95,"carbs_g":240,"fat_g":58,"sat_fat_g":12,"sodium_mg":1400,"fiber_g":30}}',
  'Your sodium has run high on several days. Let''s tighten the target a little.', 'pending');

-- ---------------------------------------------------------------- food logs (30 days, 4 per day)
-- variant = day offset mod 3; for James variant 1 dinner is the salty ramen, so 2-3 of the last 7 days exceed 1500 mg.
create temp table seed_foods (
  uid uuid, slot int, variant int, meal text, name text,
  kcal numeric, protein_g numeric, carbs_g numeric, fat_g numeric, sat_fat_g numeric, sodium_mg numeric, fiber_g numeric, sugar_g numeric
);
insert into seed_foods values
  -- Maria
  ('a0000000-0000-4000-8000-000000000002', 0, 0, 'breakfast', 'Oatmeal with berries', 300, 10, 52, 6, 1, 120, 8, 12),
  ('a0000000-0000-4000-8000-000000000002', 0, 1, 'breakfast', 'Greek yogurt with almonds', 280, 20, 18, 14, 3, 80, 3, 10),
  ('a0000000-0000-4000-8000-000000000002', 0, 2, 'breakfast', 'Veggie omelette', 290, 19, 8, 20, 6, 380, 2, 4),
  ('a0000000-0000-4000-8000-000000000002', 1, 0, 'lunch', 'Grilled chicken salad', 420, 38, 22, 20, 4, 520, 6, 7),
  ('a0000000-0000-4000-8000-000000000002', 1, 1, 'lunch', 'Lentil soup with bread', 400, 22, 60, 7, 1, 600, 14, 6),
  ('a0000000-0000-4000-8000-000000000002', 1, 2, 'lunch', 'Turkey wrap', 430, 30, 42, 15, 4, 700, 5, 4),
  ('a0000000-0000-4000-8000-000000000002', 2, 0, 'dinner', 'Baked salmon with quinoa', 520, 36, 40, 22, 4, 410, 6, 3),
  ('a0000000-0000-4000-8000-000000000002', 2, 1, 'dinner', 'Tofu stir-fry with brown rice', 480, 24, 58, 16, 2, 560, 8, 7),
  ('a0000000-0000-4000-8000-000000000002', 2, 2, 'dinner', 'Chicken with roasted vegetables', 450, 40, 28, 18, 4, 430, 7, 6),
  ('a0000000-0000-4000-8000-000000000002', 3, 0, 'snack', 'Apple with peanut butter', 190, 5, 25, 9, 2, 70, 5, 17),
  ('a0000000-0000-4000-8000-000000000002', 3, 1, 'snack', 'Carrots with hummus', 150, 5, 16, 8, 1, 180, 5, 4),
  ('a0000000-0000-4000-8000-000000000002', 3, 2, 'snack', 'Cottage cheese', 140, 14, 6, 5, 3, 330, 0, 4),
  -- James
  ('a0000000-0000-4000-8000-000000000003', 0, 0, 'breakfast', 'Oatmeal with banana', 350, 10, 62, 7, 1, 90, 8, 18),
  ('a0000000-0000-4000-8000-000000000003', 0, 1, 'breakfast', 'Egg-white scramble with toast', 330, 24, 30, 12, 3, 420, 4, 3),
  ('a0000000-0000-4000-8000-000000000003', 0, 2, 'breakfast', 'Fruit and yogurt bowl', 320, 14, 54, 6, 2, 100, 5, 30),
  ('a0000000-0000-4000-8000-000000000003', 1, 0, 'lunch', 'Grilled chicken rice bowl', 600, 42, 70, 14, 3, 380, 5, 4),
  ('a0000000-0000-4000-8000-000000000003', 1, 1, 'lunch', 'Tuna salad sandwich', 560, 34, 52, 22, 4, 640, 5, 5),
  ('a0000000-0000-4000-8000-000000000003', 1, 2, 'lunch', 'Bean burrito bowl', 580, 22, 88, 14, 3, 520, 14, 5),
  ('a0000000-0000-4000-8000-000000000003', 2, 0, 'dinner', 'Baked cod with potatoes', 560, 38, 60, 16, 3, 380, 6, 3),
  ('a0000000-0000-4000-8000-000000000003', 2, 1, 'dinner', 'Pork ramen with soy broth', 640, 28, 78, 24, 9, 1750, 3, 6),
  ('a0000000-0000-4000-8000-000000000003', 2, 2, 'dinner', 'Pasta with tomato sauce', 600, 20, 98, 14, 4, 400, 7, 12),
  ('a0000000-0000-4000-8000-000000000003', 3, 0, 'snack', 'Banana', 105, 1, 27, 0, 0, 1, 3, 14),
  ('a0000000-0000-4000-8000-000000000003', 3, 1, 'snack', 'Unsalted almonds', 170, 6, 6, 15, 1, 0, 3, 1),
  ('a0000000-0000-4000-8000-000000000003', 3, 2, 'snack', 'Apple', 95, 0, 25, 0, 0, 2, 4, 19),
  -- Alex
  ('a0000000-0000-4000-8000-000000000004', 0, 0, 'breakfast', 'Eggs, oats and banana', 760, 38, 90, 24, 8, 620, 9, 20),
  ('a0000000-0000-4000-8000-000000000004', 0, 1, 'breakfast', 'Protein pancakes', 720, 45, 85, 20, 6, 540, 7, 18),
  ('a0000000-0000-4000-8000-000000000004', 0, 2, 'breakfast', 'Breakfast burrito', 800, 42, 80, 32, 11, 980, 6, 4),
  ('a0000000-0000-4000-8000-000000000004', 1, 0, 'lunch', 'Chicken, rice and broccoli', 850, 70, 95, 16, 4, 680, 8, 3),
  ('a0000000-0000-4000-8000-000000000004', 1, 1, 'lunch', 'Beef rice bowl', 900, 62, 90, 30, 10, 760, 7, 5),
  ('a0000000-0000-4000-8000-000000000004', 1, 2, 'lunch', 'Tuna pasta', 820, 58, 100, 18, 4, 700, 6, 5),
  ('a0000000-0000-4000-8000-000000000004', 2, 0, 'dinner', 'Salmon with sweet potato', 880, 62, 80, 32, 7, 620, 10, 9),
  ('a0000000-0000-4000-8000-000000000004', 2, 1, 'dinner', 'Turkey chili with rice', 840, 64, 92, 20, 6, 880, 14, 8),
  ('a0000000-0000-4000-8000-000000000004', 2, 2, 'dinner', 'Steak with potatoes', 920, 66, 78, 38, 14, 740, 8, 3),
  ('a0000000-0000-4000-8000-000000000004', 3, 0, 'snack', 'Protein shake with banana', 350, 40, 36, 5, 2, 220, 3, 22),
  ('a0000000-0000-4000-8000-000000000004', 3, 1, 'snack', 'Greek yogurt with granola', 320, 25, 40, 8, 4, 110, 3, 20),
  ('a0000000-0000-4000-8000-000000000004', 3, 2, 'snack', 'Peanut butter sandwich', 420, 16, 42, 22, 5, 360, 4, 9);

insert into food_logs (user_id, logged_at, meal, name, serving_desc, servings,
  kcal, protein_g, carbs_g, fat_g, sat_fat_g, sodium_mg, fiber_g, sugar_g, source)
select f.uid,
  ((now() at time zone 'UTC')::date - d.n + (array['08:00','12:30','19:00','15:30'])[f.slot + 1]::time) at time zone 'UTC',
  f.meal, f.name, '1 serving', 1,
  f.kcal, f.protein_g, f.carbs_g, f.fat_g, f.sat_fat_g, f.sodium_mg, f.fiber_g, f.sugar_g, 'manual'
from seed_foods f
join generate_series(1, 30) as d(n) on d.n % 3 = f.variant;

drop table seed_foods;

-- ---------------------------------------------------------------- workouts (~4 per week)
insert into workouts (user_id, started_at, kind, duration_min, kcal, distance_km, source)
select p.id,
  ((now() at time zone 'UTC')::date - d.n + time '17:30') at time zone 'UTC',
  case p.email
    when 'maria@nutravision.demo' then case when d.n % 2 = 0 then 'walking' else 'yoga' end
    when 'james@nutravision.demo' then case when d.n % 2 = 0 then 'cycling' else 'walking' end
    else (array['strength', 'running', 'hiit'])[d.n % 3 + 1]
  end,
  case p.email when 'alex@nutravision.demo' then 60 else 40 end,
  case p.email when 'maria@nutravision.demo' then 160 when 'james@nutravision.demo' then 280 else 450 end,
  case p.email
    when 'maria@nutravision.demo' then case when d.n % 2 = 0 then 3.5 end
    when 'james@nutravision.demo' then case when d.n % 2 = 0 then 12 else 3.2 end
    else case when d.n % 3 = 1 then 7 end
  end,
  'manual'
from profiles p
join generate_series(1, 30) as d(n) on d.n % 7 in (1, 3, 5, 6)
where p.role = 'patient';

-- ---------------------------------------------------------------- weekly weights (12 weeks, trending to goal)
insert into weight_logs (user_id, measured_at, weight_kg, source)
select p.id,
  ((now() at time zone 'UTC')::date - 7 * w.n + time '07:30') at time zone 'UTC',
  round(p.weight_kg - p.weekly_rate_kg * w.n + case when w.n > 0 then ((w.n * 7) % 3 - 1) * 0.1 else 0 end, 1),
  'manual'
from profiles p
cross join generate_series(0, 11) as w(n)
where p.role = 'patient';
