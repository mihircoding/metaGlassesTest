-- What a clinic following diabetes, hypertension, heart and kidney patients needs between visits:
-- blood pressure and glucose readings, fluid intake against a limit, and doctors' private notes.

create table vital_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  measured_at timestamptz not null,
  kind text not null check (kind in ('glucose', 'blood_pressure')),
  glucose_mg_dl numeric check (glucose_mg_dl between 10 and 1000),
  glucose_context text check (glucose_context in ('fasting', 'before_meal', 'after_meal', 'bedtime', 'other')),
  systolic integer check (systolic between 50 and 300),
  diastolic integer check (diastolic between 30 and 200),
  pulse integer check (pulse between 20 and 250),
  note text check (char_length(note) <= 500),
  check ((kind = 'glucose' and glucose_mg_dl is not null and systolic is null and diastolic is null)
      or (kind = 'blood_pressure' and systolic is not null and diastolic is not null and glucose_mg_dl is null))
);
create index vital_logs_user_measured_idx on vital_logs (user_id, measured_at);

create table fluid_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  logged_at timestamptz not null,
  ml numeric not null check (ml > 0 and ml <= 5000)
);
create index fluid_logs_user_logged_idx on fluid_logs (user_id, logged_at);

-- Set by the patient from what their doctor told them; null = no limit.
alter table profiles add column fluid_limit_ml numeric check (fluid_limit_ml > 0);

create table clinical_notes (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  doctor_id uuid not null references profiles on delete cascade,
  patient_id uuid not null references profiles on delete cascade,
  body text not null check (char_length(body) between 1 and 4000)
);
create index clinical_notes_doctor_patient_idx on clinical_notes (doctor_id, patient_id, created_at);

alter table vital_logs enable row level security;
alter table fluid_logs enable row level security;
alter table clinical_notes enable row level security;

create policy vital_logs_own on vital_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy vital_logs_doctor on vital_logs for select using (is_doctor_of(user_id));
create policy fluid_logs_own on fluid_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy fluid_logs_doctor on fluid_logs for select using (is_doctor_of(user_id));
-- A doctor's notes are theirs alone, and only while the patient shares with them.
create policy clinical_notes_doctor on clinical_notes for all
  using (doctor_id = auth.uid() and is_doctor_of(patient_id))
  with check (doctor_id = auth.uid() and is_doctor_of(patient_id));

revoke all on vital_logs, fluid_logs, clinical_notes from anon, authenticated;
grant select, insert, update, delete on vital_logs, fluid_logs to authenticated;
grant select, insert, delete on clinical_notes to authenticated;
