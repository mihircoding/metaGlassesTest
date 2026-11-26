-- A symptom diary for digestive conditions (IBS, IBD, celiac disease, EoE): what the patient felt,
-- how bad it was and, optionally, their stool type on the Bristol scale. Doctors they share with can read it.

create table symptom_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references profiles on delete cascade,
  logged_at timestamptz not null,
  symptoms text[] not null check (
    cardinality(symptoms) between 1 and 12
    and symptoms <@ array['abdominal_pain', 'bloating', 'gas', 'diarrhea', 'constipation', 'urgency', 'nausea',
                          'heartburn', 'trouble_swallowing', 'food_stuck', 'fatigue', 'blood_in_stool']::text[]),
  severity integer not null check (severity between 1 and 10),
  bristol integer check (bristol between 1 and 7),
  note text check (char_length(note) <= 500)
);
create index symptom_logs_user_logged_idx on symptom_logs (user_id, logged_at);

alter table symptom_logs enable row level security;
create policy symptom_logs_own on symptom_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy symptom_logs_doctor on symptom_logs for select using (is_doctor_of(user_id));

revoke all on symptom_logs from anon, authenticated;
grant select, insert, update, delete on symptom_logs to authenticated;
