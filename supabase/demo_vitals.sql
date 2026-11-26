-- Blood pressure, glucose and fluids for the demo patients, for the last 30 days. Run once after
-- seed.sql and migration 0006; re-running does nothing. demo_refresh.sql moves these forward too.
do $$
declare
  -- The demo diary's newest day, so readings and food stay in step when demo_refresh moves them.
  base date := coalesce((select max(f.logged_at)::date from food_logs f join profiles p on p.id = f.user_id
                         where p.email like '%@nutravision.demo'), current_date);
begin
  if exists (select 1 from vital_logs v join profiles p on p.id = v.user_id where p.email like '%@nutravision.demo') then
    raise notice 'Demo vitals already exist';
    return;
  end if;

  -- James (hypertension): a morning reading each day, coming down from stage 2 toward stage 1,
  -- with two high spikes for the doctor to notice.
  insert into vital_logs (user_id, measured_at, kind, systolic, diastolic, pulse)
  select 'a0000000-0000-4000-8000-000000000003',
    (base - d.n + time '07:15') at time zone 'UTC', 'blood_pressure',
    148 - (30 - d.n) / 3 + (d.n * 7) % 5 + case when d.n in (3, 11) then 14 else 0 end,
    94 - (30 - d.n) / 5 + (d.n * 3) % 4,
    68 + (d.n * 5) % 9
  from generate_series(0, 29) as d(n);

  -- Maria (type 2 diabetes): fasting glucose each morning, after-dinner checks every third day,
  -- and one low at bedtime.
  insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl, glucose_context)
  select 'a0000000-0000-4000-8000-000000000002',
    (base - d.n + time '06:45') at time zone 'UTC', 'glucose',
    124 - (30 - d.n) / 4 + (d.n * 11) % 17, 'fasting'
  from generate_series(0, 29) as d(n);
  insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl, glucose_context)
  select 'a0000000-0000-4000-8000-000000000002',
    (base - d.n + time '20:30') at time zone 'UTC', 'glucose',
    160 + (d.n * 13) % 40, 'after_meal'
  from generate_series(1, 29, 3) as d(n);
  insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl, glucose_context, note)
  values ('a0000000-0000-4000-8000-000000000002',
    (base - 5 + time '22:30') at time zone 'UTC', 'glucose', 64, 'bedtime',
    'Skipped dinner. Had juice and rechecked: 98.');

  -- Maria's water: four drinks a day for the last two weeks.
  insert into fluid_logs (user_id, logged_at, ml)
  select 'a0000000-0000-4000-8000-000000000002',
    (base - d.n + make_time(8 + 3 * k.k, 0, 0)) at time zone 'UTC',
    case when k.k % 2 = 0 then 250 else 500 end
  from generate_series(1, 13) as d(n) cross join generate_series(0, 3) as k(k);
end $$;
