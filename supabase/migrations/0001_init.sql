-- NutraVision schema, RLS and doctor-patient functions (spec section 3).
-- Expects Supabase's auth schema, auth.uid() and the anon/authenticated roles to exist.

-- ---------------------------------------------------------------- tables

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  role text not null default 'patient' check (role in ('patient', 'doctor')),
  full_name text,
  email text,
  birth_date date,
  sex text check (sex in ('male', 'female', 'unspecified')),
  height_cm numeric check (height_cm > 0),
  weight_kg numeric check (weight_kg > 0),
  activity text check (activity in ('sedentary', 'light', 'moderate', 'very', 'extra')),
  conditions text[] not null default '{general}',
  goal_weight_kg numeric check (goal_weight_kg > 0),
  weekly_rate_kg numeric check (weekly_rate_kg between -1 and 1),
  -- active daily targets (defaults = Targets.defaults in NutraCore)
  kcal_target numeric not null default 2000 check (kcal_target >= 0),
  protein_g numeric not null default 100 check (protein_g >= 0),
  carbs_g numeric not null default 250 check (carbs_g >= 0),
  fat_g numeric not null default 67 check (fat_g >= 0),
  sat_fat_g numeric not null default 22 check (sat_fat_g >= 0),
  sodium_mg numeric not null default 2300 check (sodium_mg >= 0),
  fiber_g numeric not null default 28 check (fiber_g >= 0),
  targets_source text not null default 'auto' check (targets_source in ('auto', 'custom', 'doctor')),
  add_exercise_kcal boolean not null default true,
  specialty text,
  license_number text
);
create index profiles_email_idx on profiles (email);

create table food_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  logged_at timestamptz not null,
  meal text not null check (meal in ('breakfast', 'lunch', 'dinner', 'snack')),
  name text not null,
  brand text,
  serving_desc text,
  serving_grams numeric check (serving_grams > 0),
  servings numeric not null default 1 check (servings > 0),
  kcal numeric not null default 0 check (kcal >= 0),
  protein_g numeric not null default 0 check (protein_g >= 0),
  carbs_g numeric not null default 0 check (carbs_g >= 0),
  fat_g numeric not null default 0 check (fat_g >= 0),
  sat_fat_g numeric not null default 0 check (sat_fat_g >= 0),
  sodium_mg numeric not null default 0 check (sodium_mg >= 0),
  fiber_g numeric not null default 0 check (fiber_g >= 0),
  sugar_g numeric not null default 0 check (sugar_g >= 0),
  source text not null check (source in ('manual', 'search', 'barcode', 'glasses_ai', 'photo_ai', 'plan')),
  source_ref text,
  ai_confidence text,
  scan_id uuid
);
create index food_logs_user_logged_idx on food_logs (user_id, logged_at);

create table custom_foods (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  name text not null,
  brand text,
  serving_desc text,
  serving_grams numeric check (serving_grams > 0),
  kcal numeric not null default 0 check (kcal >= 0),
  protein_g numeric not null default 0 check (protein_g >= 0),
  carbs_g numeric not null default 0 check (carbs_g >= 0),
  fat_g numeric not null default 0 check (fat_g >= 0),
  sat_fat_g numeric not null default 0 check (sat_fat_g >= 0),
  sodium_mg numeric not null default 0 check (sodium_mg >= 0),
  fiber_g numeric not null default 0 check (fiber_g >= 0),
  sugar_g numeric not null default 0 check (sugar_g >= 0)
);
create index custom_foods_user_idx on custom_foods (user_id);

create table workouts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  started_at timestamptz not null,
  kind text not null check (kind in ('running', 'walking', 'cycling', 'swimming', 'strength', 'hiit', 'yoga', 'other')),
  duration_min numeric not null default 0 check (duration_min >= 0),
  kcal numeric not null default 0 check (kcal >= 0),
  distance_km numeric check (distance_km >= 0),
  notes text,
  source text not null default 'manual' check (source in ('manual', 'healthkit')),
  healthkit_uuid text,
  unique (user_id, healthkit_uuid)
);
create index workouts_user_started_idx on workouts (user_id, started_at);

create table weight_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  measured_at timestamptz not null,
  weight_kg numeric not null check (weight_kg > 0),
  source text not null default 'manual' check (source in ('manual', 'healthkit')),
  healthkit_uuid text,
  unique (user_id, healthkit_uuid)
);
create index weight_logs_user_measured_idx on weight_logs (user_id, measured_at);

create table diet_plans (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  author_id uuid not null references profiles on delete cascade,
  condition_id text,
  name text not null,
  notes text,
  targets jsonb not null default '{}',
  meals jsonb not null default '[]',
  is_active boolean not null default false
);
create unique index diet_plans_one_active_idx on diet_plans (user_id) where is_active;

create table care_links (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  doctor_id uuid not null references profiles on delete cascade,
  patient_id uuid not null references profiles on delete cascade,
  patient_email text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'revoked')),
  responded_at timestamptz,
  unique (doctor_id, patient_id)
);
create index care_links_patient_idx on care_links (patient_id);

create table recommendations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  doctor_id uuid not null references profiles on delete cascade,
  patient_id uuid not null references profiles on delete cascade,
  kind text not null check (kind in ('targets', 'diet_plan', 'note')),
  payload jsonb not null default '{}',
  message text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  responded_at timestamptz
);
create index recommendations_patient_idx on recommendations (patient_id, status);
create index recommendations_doctor_idx on recommendations (doctor_id);

-- ---------------------------------------------------------------- triggers

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, role, full_name, email)
  values (new.id,
          coalesce(new.raw_user_meta_data ->> 'role', 'patient'),
          new.raw_user_meta_data ->> 'full_name',
          lower(new.email));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

create function lock_role() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.role <> old.role then raise exception 'Role cannot be changed'; end if;
  return new;
end $$;

create trigger profiles_lock_role before update on profiles
  for each row execute function lock_role();

-- ---------------------------------------------------------------- functions

create function is_doctor_of(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from care_links
                 where doctor_id = auth.uid() and patient_id = p and status = 'accepted') $$;

create function request_patient(patient_email text) returns care_links
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  pid uuid;
  link care_links;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'doctor') then
    raise exception 'Only doctors can send requests';
  end if;
  select id into pid from profiles
   where email = lower(trim(request_patient.patient_email)) and role = 'patient';
  if pid is null then raise exception 'No patient with that email'; end if;

  -- an accepted link is left alone; declined/revoked/pending are reset to pending
  insert into care_links (doctor_id, patient_id, patient_email, status)
  values (auth.uid(), pid, trim(request_patient.patient_email), 'pending')
  on conflict (doctor_id, patient_id) do update
    set status = 'pending', responded_at = null, patient_email = excluded.patient_email
    where care_links.status <> 'accepted';

  select * into link from care_links where doctor_id = auth.uid() and patient_id = pid;
  return link;
end $$;

create function respond_care_link(link_id uuid, accept boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  update care_links
     set status = case when accept then 'accepted' else 'declined' end, responded_at = now()
   where id = link_id and patient_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Request not found'; end if;
end $$;

create function accept_recommendation(rec_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  rec recommendations;
  t jsonb;
  plan jsonb;
begin
  select * into rec from recommendations
   where id = rec_id and patient_id = auth.uid() and status = 'pending' for update;
  if not found then raise exception 'Recommendation not found'; end if;

  if rec.kind = 'targets' then
    t := rec.payload -> 'targets';
    update profiles set
      kcal_target = coalesce((t ->> 'kcal_target')::numeric, kcal_target),
      protein_g   = coalesce((t ->> 'protein_g')::numeric, protein_g),
      carbs_g     = coalesce((t ->> 'carbs_g')::numeric, carbs_g),
      fat_g       = coalesce((t ->> 'fat_g')::numeric, fat_g),
      sat_fat_g   = coalesce((t ->> 'sat_fat_g')::numeric, sat_fat_g),
      sodium_mg   = coalesce((t ->> 'sodium_mg')::numeric, sodium_mg),
      fiber_g     = coalesce((t ->> 'fiber_g')::numeric, fiber_g),
      targets_source = 'doctor'
    where id = rec.patient_id;
  elsif rec.kind = 'diet_plan' then
    plan := rec.payload -> 'diet_plan';
    update diet_plans set is_active = false where user_id = rec.patient_id and is_active;
    insert into diet_plans (user_id, author_id, condition_id, name, notes, targets, meals, is_active)
    values (rec.patient_id, rec.doctor_id, plan ->> 'condition_id', plan ->> 'name', plan ->> 'notes',
            coalesce(plan -> 'targets', '{}'), coalesce(plan -> 'meals', '[]'), true);
  end if;

  update recommendations set status = 'accepted', responded_at = now() where id = rec_id;
end $$;

-- ---------------------------------------------------------------- RLS

alter table profiles enable row level security;
alter table food_logs enable row level security;
alter table custom_foods enable row level security;
alter table workouts enable row level security;
alter table weight_logs enable row level security;
alter table diet_plans enable row level security;
alter table care_links enable row level security;
alter table recommendations enable row level security;

-- profiles: own row; linked doctor reads patient; patient reads any doctor joined by a link
create policy profiles_select_own on profiles for select using (id = auth.uid());
create policy profiles_update_own on profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_select_doctor on profiles for select using (is_doctor_of(id));
create policy profiles_select_my_doctor on profiles for select
  using (exists (select 1 from care_links l where l.patient_id = auth.uid() and l.doctor_id = profiles.id));

-- owner-all + linked-doctor-select tables
create policy food_logs_own on food_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy food_logs_doctor on food_logs for select using (is_doctor_of(user_id));
create policy custom_foods_own on custom_foods for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy custom_foods_doctor on custom_foods for select using (is_doctor_of(user_id));
create policy workouts_own on workouts for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy workouts_doctor on workouts for select using (is_doctor_of(user_id));
create policy weight_logs_own on weight_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy weight_logs_doctor on weight_logs for select using (is_doctor_of(user_id));

-- diet_plans: owner can only write plans they authored themselves
create policy diet_plans_select_own on diet_plans for select using (user_id = auth.uid());
create policy diet_plans_insert_own on diet_plans for insert
  with check (user_id = auth.uid() and author_id = auth.uid());
create policy diet_plans_update_own on diet_plans for update
  using (user_id = auth.uid()) with check (user_id = auth.uid() and author_id = auth.uid());
create policy diet_plans_delete_own on diet_plans for delete using (user_id = auth.uid());
create policy diet_plans_doctor on diet_plans for select using (is_doctor_of(user_id));

-- care_links: no insert policy (request_patient only); column grant limits updates to status
create policy care_links_select on care_links for select
  using (patient_id = auth.uid() or doctor_id = auth.uid());
create policy care_links_patient_update on care_links for update
  using (patient_id = auth.uid()) with check (patient_id = auth.uid() and status = 'revoked');
create policy care_links_doctor_update on care_links for update
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid() and status = 'revoked');

-- recommendations: accepting only via accept_recommendation
create policy recommendations_select on recommendations for select
  using (patient_id = auth.uid() or doctor_id = auth.uid());
create policy recommendations_doctor_insert on recommendations for insert
  with check (doctor_id = auth.uid() and status = 'pending' and is_doctor_of(patient_id));
create policy recommendations_patient_decline on recommendations for update
  using (patient_id = auth.uid() and status = 'pending') with check (patient_id = auth.uid() and status = 'declined');

-- ---------------------------------------------------------------- grants
-- Supabase grants everything to anon/authenticated by default; start from nothing.

revoke all on all tables in schema public from anon, authenticated;
grant select, insert, update, delete on profiles, food_logs, custom_foods, workouts, weight_logs, diet_plans to authenticated;
grant select on care_links, recommendations to authenticated;
grant insert on recommendations to authenticated;
grant update (status) on care_links, recommendations to authenticated;

revoke execute on function is_doctor_of(uuid), request_patient(text), respond_care_link(uuid, boolean),
  accept_recommendation(uuid), handle_new_user(), lock_role() from public, anon;
grant execute on function is_doctor_of(uuid), request_patient(text), respond_care_link(uuid, boolean),
  accept_recommendation(uuid) to authenticated;
